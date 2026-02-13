package dev.adampalinkas.flutter_mindful_minutes

import FlutterMindfulMinutesHostApi
import android.content.Context
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
import java.time.Instant
import java.time.ZoneOffset


/** FlutterMindfulMinutesPlugin */
class FlutterMindfulMinutesPlugin() :
    FlutterPlugin,
    ActivityAware,
    FlutterMindfulMinutesHostApi {

    private var context: Context? = null

    private var activityBinding: ActivityPluginBinding? = null
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingResult: MethodChannel.Result? = null

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

    override fun isAvailable(callback: (Result<Boolean>) -> Unit) {
        log("Checking is functionality is available")
        val ctx = context

        if (ctx == null) {
            callback(Result.failure(Exception("Context is null, cannot check HealthConnect SDK availability")))
            return
        }

        val isHealthConnectSDKAvailable = checkHealthConnectSDKAvailability()
        if (!isHealthConnectSDKAvailable) {
            log("Health Connect SDK is not available")
            callback(Result.success(false))
            return
        }

        val healthConnectClient = HealthConnectClient.getOrCreate(ctx)
        val isMindfulnessSupported = checkMindfulnessSupport(healthConnectClient)

        if (!isMindfulnessSupported) {
            log("MindfulnessSessionRecord is not supported, try to update Google Play Services")
            callback(Result.success(false))
            return
        }

        val activity = activityBinding?.activity as? FlutterFragmentActivity
        if (activity == null) {
            log("Cannot cast activity to FlutterFragmentActivity, does your MainActivity extend FlutterFragmentActivity?")
            callback(Result.success(false))
            return
        }

        log("Mindful minutes is supported")
        callback(Result.success(true))
    }

    override fun requestPermission(callback: (Result<Boolean>) -> Unit) {
        log("requestMindfulMinutesAuthorization")
        scope.launch {
            // Check if permissions are already granted
            try {
                val healthConnectClient = HealthConnectClient.getOrCreate(activityBinding!!.activity)
                val isSupported = checkMindfulnessSupport(healthConnectClient)
                if (!isSupported) {
                    Log.e("HealthConnect", "Mindfulness is not yet supported on this device's OS version.")
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
                        activityBinding?.activity?.runOnUiThread {
                            launcher.launch(permissions)
                        }
                    } else {
                        callback(Result.failure(Exception("Permission launcher is not initialized. Extended your projects MainActivity with FlutterFragmentActivity instead of FlutterActivity?")))
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
        pendingResult?.success(allGranted)
        pendingResult = null
    }

    override fun writeMindfulMinutes(
        startSeconds: Long,
        endSeconds: Long,
        callback: (Result<Boolean>) -> Unit
    ) {
        log("Writing mindful minutes")
        scope.launch {
            try {
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

    fun checkHealthConnectSDKAvailability(): Boolean {
        val ctx = context ?: throw Exception("Context is null, cannot check availability")

        val sdkStatus = HealthConnectClient.getSdkStatus(ctx)
        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE) {
            log("Health Connect SDK is not available")
            return false

        }
        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            log("Health Connect provider update required")
            return false
        }

        if (sdkStatus == HealthConnectClient.SDK_AVAILABLE) {
            log("Health Connect SDK is available")
            return true
        }

        return false
    }

    fun checkMindfulnessSupport(healthConnectClient: HealthConnectClient) : Boolean {
        val status = healthConnectClient.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
        )
        return (status == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE)
    }

}