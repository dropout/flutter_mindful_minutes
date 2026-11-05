package dev.adampalinkas.flutter_mindful_minutes

import AuthorizationStatus
import FlutterMindfulMinutesHostApi
import FlutterMindfulMinutesPluginError
import RequestStatusForAuthorization
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import io.flutter.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import java.time.Instant
import java.time.ZoneOffset







/** Error codes sent to the Dart side, they have to match `MindfulMinutesErrorCodes` in Dart. */
object ErrorCodes {
    const val HEALTH_DATA_UNAVAILABLE = "health_data_unavailable"
    const val PROVIDER_UPDATE_REQUIRED = "provider_update_required"
    const val MINDFULNESS_NOT_SUPPORTED = "mindfulness_not_supported"
    const val ACTIVITY_NOT_SUPPORTED = "activity_not_supported"
    const val MISSING_PERMISSION_DECLARATION = "missing_permission_declaration"
}

/** FlutterMindfulMinutesPlugin */
class FlutterMindfulMinutesPlugin() :
    FlutterPlugin,
    ActivityAware,
    FlutterMindfulMinutesHostApi {

    private var context: Context? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingAuthorizationCallback: ((Result<Boolean>) -> Unit)? = null

    private val scope = CoroutineScope(Dispatchers.Main)

    private val permissions = setOf(
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class)
    )

    fun log(message: String) = Log.d("FlutterMindfulMinutesPlugin", message)

    /**
     *  FlutterPlugin
     */

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        log("Attached to engine")
        context = flutterPluginBinding.applicationContext
        FlutterMindfulMinutesHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        log("Detached from engine")
        FlutterMindfulMinutesHostApi.setUp(binding.binaryMessenger, this)
        context = null
    }

    /**
     *  ActivityAware
     */

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        log("Attached to activity")
        activityBinding = binding

        val activity = binding.activity as? FlutterFragmentActivity
        if (activity != null) {
            Log.d("FlutterMindfulMinutesPlugin", "Initializing permission launcher")
            val contract = PermissionController.createRequestPermissionResultContract()
            permissionLauncher = activity.registerForActivityResult(contract) { grantedPermissions ->
                handlePermissionResult(grantedPermissions)
            }
        } else {
            Log.d("FlutterMindfulMinutesPlugin", "Activity is null, can't register permission launcher")
        }
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
        permissionLauncher = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }

    /*
     *  FlutterMindfulMinutesHostApi
     */

    override fun checkAvailability(callback: (Result<Unit>) -> Unit) {
        log("Checking if functionality is available")
        val ctx = context

        if (ctx == null) {
            callback(Result.failure(Exception("Context is null, cannot check HealthConnect SDK availability")))
            return
        }

        when (HealthConnectClient.getSdkStatus(ctx)) {
            HealthConnectClient.SDK_AVAILABLE -> log("Health Connect SDK is available")
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                log("Health Connect provider update required")
                callback(Result.failure(FlutterMindfulMinutesPluginError(
                    ErrorCodes.PROVIDER_UPDATE_REQUIRED,
                    "The Health Connect provider has to be installed or updated."
                )))
                return
            }
            else -> {
                log("Health Connect SDK is not available")
                callback(Result.failure(FlutterMindfulMinutesPluginError(
                    ErrorCodes.HEALTH_DATA_UNAVAILABLE,
                    "Health Connect is not available on this device."
                )))
                return
            }
        }

        val healthConnectClient = HealthConnectClient.getOrCreate(ctx)
        if (!checkMindfulnessSupport(healthConnectClient)) {
            log("MindfulnessSessionRecord is not supported, try to update Google Play Services")
            callback(Result.failure(mindfulnessNotSupportedError()))
            return
        }

        if (activityBinding?.activity !is FlutterFragmentActivity) {
            log("Cannot cast activity to FlutterFragmentActivity, does your MainActivity extend FlutterFragmentActivity?")
            callback(Result.failure(activityNotSupportedError()))
            return
        }

        log("Mindful minutes is supported")
        callback(Result.success(Unit))
    }


    override fun getRequestForAuthorizationStatus(callback: (Result<RequestStatusForAuthorization>) -> Unit) {
        val ctx = context
        if (ctx == null) {
            callback(Result.failure(Exception("Context is null, cannot check status for authorization request.")))
            return
        }

        // Check if the permission was granted previously
        val healthConnectClient = HealthConnectClient.getOrCreate(ctx)
        var hasGrantedPermissions = false
        runBlocking {
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            hasGrantedPermissions = granted.containsAll(permissions)
        }

        // Has granted permissions already no need to request permission and display system ui
        if (hasGrantedPermissions) {
            callback(Result.success(RequestStatusForAuthorization.UNNECESSARY))
            return
        }

        val denialCounter = PermissionDenialCounter(ctx)
        var isOverLimit = false
        var denialCount = 0
        runBlocking {
            isOverLimit = denialCounter.isOverLimit(getCombinedKey(permissions))
            denialCount = denialCounter.getDenialCount(getCombinedKey(permissions))
        }

        // Permissions not granted but request permission system ui has been exhausted
        if (isOverLimit) {
            callback(Result.success(RequestStatusForAuthorization.UNNECESSARY))
            log("Showing request permission system ui has been exhausted, Denial count: $denialCount, isOverLimit: $isOverLimit, hasGrantedPermissions: $hasGrantedPermissions")
            return
        }

        // No permissions granted and request permission system ui has not been exhausted
        log("A request for permission can be performed, Denial count: $denialCount, isOverLimit: $isOverLimit, hasGrantedPermissions: $hasGrantedPermissions")
        callback(Result.success(RequestStatusForAuthorization.SHOULD_REQUEST))
    }

    override fun getAuthorizationStatus(callback: (Result<AuthorizationStatus>) -> Unit) {
        val healthConnectClient = HealthConnectClient.getOrCreate(activityBinding!!.activity)
        scope.launch {
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (granted.containsAll(permissions)) {
                callback(Result.success(AuthorizationStatus.AUTHORIZED))
            } else {
                callback(Result.success(AuthorizationStatus.DENIED))
            }
        }
    }

    override fun requestAuthorization(callback: (Result<Boolean>) -> Unit) {
        log("requestMindfulMinutesAuthorization")
        scope.launch {
            // Check if permissions are already granted
            try {
                val healthConnectClient = HealthConnectClient.getOrCreate(activityBinding!!.activity)
                val isSupported = checkMindfulnessSupport(healthConnectClient)
                if (!isSupported) {
                    Log.e("HealthConnect", "Mindfulness is not yet supported on this device's OS version.")
                    // Return failure callback instead of just silent return
                    callback(Result.failure(mindfulnessNotSupportedError()))
                    return@launch
                }
                if (!arePermissionsDeclared()) {
                    callback(Result.failure(missingPermissionDeclarationError()))
                    return@launch
                }
                val granted = healthConnectClient.permissionController.getGrantedPermissions()
                if (granted.containsAll(permissions)) {
                    Log.d("FlutterMindfulMinutesPlugin", "Permissions are granted: $granted")
                    callback(Result.success(true))
                } else {
                    Log.d("FlutterMindfulMinutesPlugin", "Permissions are not granted: $granted")
                    val launcher = permissionLauncher
                    if (launcher != null) {
                        Log.d("FlutterMindfulMinutesPlugin", "Requesting permissions: $permissions")
                        pendingAuthorizationCallback = callback
                        activityBinding?.activity?.runOnUiThread {
                            launcher.launch(permissions)
                        }
                    } else {
                        callback(Result.failure(activityNotSupportedError()))
                    }
                }
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    private fun handlePermissionResult(granted: Set<String>) {
        log("handlePermissionResult: $granted")
        val allGranted = granted.containsAll(permissions)

        // check if permissions were granted and
        // if not increment the denial counter
        if (!allGranted) {
            if (context == null) {
                log("Context is null, cannot increment denial counter")
                return
            }
            val denialCounter = PermissionDenialCounter(context!!)
            scope.launch {
                denialCounter.incrementDenialCount(getCombinedKey(permissions))
            }
        }

        pendingAuthorizationCallback?.invoke(Result.success(allGranted))
        pendingAuthorizationCallback = null
    }

    override fun writeMindfulMinutes(
        startSeconds: Long,
        endSeconds: Long,
        callback: (Result<Boolean>) -> Unit
    ) {
        log("Writing mindful minutes")
        scope.launch {
            try {
                if (!arePermissionsDeclared()) {
                    callback(Result.failure(missingPermissionDeclarationError()))
                    return@launch
                }
                val healthConnectClient = HealthConnectClient.getOrCreate(activityBinding!!.activity)
                val record = MindfulnessSessionRecord(
                    startTime = Instant.ofEpochSecond(startSeconds),
                    startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(Instant.now()),
                    endTime = Instant.ofEpochSecond(endSeconds),
                    endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(Instant.now()),
                    mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MEDITATION,
                    title = "Meditation",
                    metadata = Metadata.manualEntry()
                )
                healthConnectClient.insertRecords(listOf(record))
                callback(Result.success(true))
            } catch(e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    /** Checks that every required Health Connect permission is declared in the app's manifest. */
    private fun arePermissionsDeclared(): Boolean {
        val ctx = context ?: return true
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.packageManager.getPackageInfo(
                ctx.packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.GET_PERMISSIONS)
        }
        val declared = packageInfo.requestedPermissions?.toSet() ?: emptySet()
        val missing = permissions - declared
        if (missing.isNotEmpty()) {
            log("Permissions are not declared in AndroidManifest.xml: $missing")
        }
        return missing.isEmpty()
    }

    private fun mindfulnessNotSupportedError() = FlutterMindfulMinutesPluginError(
        ErrorCodes.MINDFULNESS_NOT_SUPPORTED,
        "Mindfulness sessions are not supported by Health Connect on this device. Updating Google Play services may help."
    )

    private fun activityNotSupportedError() = FlutterMindfulMinutesPluginError(
        ErrorCodes.ACTIVITY_NOT_SUPPORTED,
        "Permission launcher is not initialized. Extend your project's MainActivity from FlutterFragmentActivity instead of FlutterActivity."
    )

    private fun missingPermissionDeclarationError() = FlutterMindfulMinutesPluginError(
        ErrorCodes.MISSING_PERMISSION_DECLARATION,
        "Missing permission declaration. Add <uses-permission android:name=\"${permissions.joinToString()}\"/> to your app's AndroidManifest.xml."
    )

    fun checkMindfulnessSupport(healthConnectClient: HealthConnectClient) : Boolean {
        val status = healthConnectClient.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
        )
        return (status == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE)
    }

    private fun getCombinedKey(permissions: Set<String>): String {
        return permissions.sorted().joinToString(",").hashCode().toString()
    }

}