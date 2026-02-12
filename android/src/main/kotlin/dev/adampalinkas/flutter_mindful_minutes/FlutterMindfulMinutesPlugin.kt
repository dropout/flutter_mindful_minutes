package dev.adampalinkas.flutter_mindful_minutes

import FlutterMindfulMinutesHostApi
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.WeightRecord
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


/** FlutterMindfulMinutesPlugin */
class FlutterMindfulMinutesPlugin() :
    FlutterPlugin,
    ActivityAware,
    FlutterMindfulMinutesHostApi {

    private var activityBinding: ActivityPluginBinding? = null
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingResult: MethodChannel.Result? = null

    private val scope = CoroutineScope(Dispatchers.Main)

    private val permissions = setOf(
//        HealthPermission.getReadPermission(MindfulnessSessionRecord::class),
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class)
    )

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("FlutterMindfulMinutesPlugin", "Attached to engine")
        FlutterMindfulMinutesHostApi.setUp(flutterPluginBinding.binaryMessenger, this)

        val sdkStatus = HealthConnectClient.getSdkStatus(flutterPluginBinding.applicationContext)
        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE) {
            Log.d("FlutterMindfulMinutesPlugin", "Health Connect is not available")
        }
        if (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED) {
            Log.d("FlutterMindfulMinutesPlugin", "Health Connect provider update required")
        }

        if (sdkStatus == HealthConnectClient.SDK_AVAILABLE) {
            Log.d("FlutterMindfulMinutesPlugin", "Health Connect SDK is available")
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d("FlutterMindfulMinutesPlugin", "Attached to activity")
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

    override fun requestMindfulMinutesAuthorization(callback: (Result<Boolean>) -> Unit) {
        Log.d("FlutterMindfulMinutesPlugin", "requestMindfulMinutesAuthorization")



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
        Log.d("FlutterMindfulMinutesPlugin", "handlePermissionResult: $granted")
        val allGranted = granted.containsAll(permissions)
        pendingResult?.success(allGranted)
        pendingResult = null
    }

    override fun writeMindfulMinutes(
        startSeconds: Long,
        endSeconds: Long,
        callback: (Result<Boolean>) -> Unit
    ) {
        print("writeMindfulMinutes")
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

    // Required overrides for ActivityAware
    override fun onDetachedFromActivity() {
        activityBinding = null
        permissionLauncher = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        FlutterMindfulMinutesHostApi.setUp(binding.binaryMessenger, this)
    }

    fun checkMindfulnessSupport(healthConnectClient: HealthConnectClient) : Boolean {
        val status = healthConnectClient.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
        )
        return status == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    }

}