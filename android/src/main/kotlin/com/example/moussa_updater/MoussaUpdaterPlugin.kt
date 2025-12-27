package com.moussa.updater

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.annotation.NonNull
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MoussaupdaterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private var activity: Activity? = null
  private var appUpdateManager: AppUpdateManager? = null

  private val REQ_CODE_UPDATE = 9911

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "moussa_updater/methods")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    appUpdateManager = AppUpdateManagerFactory.create(binding.activity)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    appUpdateManager = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    appUpdateManager = AppUpdateManagerFactory.create(binding.activity)
  }

  override fun onDetachedFromActivity() {
    activity = null
    appUpdateManager = null
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      "checkAndMaybeUpdate" -> handleCheckAndMaybeUpdate(call, result)
      "openStore" -> {
        val pkgId = call.argument<String>("androidPackageId") ?: activity?.packageName ?: ""
        openPlayStore(pkgId)
        result.success(null)
      }
      "completeFlexibleUpdate" -> {
        try {
          appUpdateManager?.completeUpdate()
          result.success(null)
        } catch (e: Exception) {
          result.error("COMPLETE_ERROR", e.message, null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun handleCheckAndMaybeUpdate(call: MethodCall, result: MethodChannel.Result) {
    val act = activity
    if (act == null) {
      result.success(mapOf(
        "action" to "ERROR",
        "platform" to "android",
        "reason" to "NO_ACTIVITY"
      ))
      return
    }

    val minVersion = call.argument<String>("minVersion") ?: "0.0.0"
    val mode = call.argument<String>("androidUpdateMode") ?: "immediate"
    val pkgId = call.argument<String>("androidPackageId") ?: act.packageName
    val playOnly = call.argument<Boolean>("playOnly") ?: false

    val current = getCurrentVersionName(act)
    val installerSource = getInstallerSource(act, act.packageName)

    val needsForce = isVersionLower(current, minVersion)

    // ✅ 1) Play-only gate: block any non-Play install
    if (playOnly && installerSource != "play_store") {
      result.success(mapOf(
        "action" to "FORCE_BLOCKED",
        "platform" to "android",
        "currentVersion" to current,
        "minVersion" to minVersion,
        "installerSource" to installerSource,
        "reason" to "NOT_PLAY_INSTALL",
        "storeUrl" to "https://play.google.com/store/apps/details?id=$pkgId"
      ))
      return
    }

    // ✅ 2) If not below min => ok
    if (!needsForce) {
      result.success(mapOf(
        "action" to "UP_TO_DATE",
        "platform" to "android",
        "currentVersion" to current,
        "minVersion" to minVersion,
        "installerSource" to installerSource
      ))
      return
    }

    // ✅ 3) Below minVersion:
    //    - If from Play Store => auto start in-app update (Immediate/Flexible)
    //    - Else => block + open store
    if (installerSource != "play_store") {
      result.success(mapOf(
        "action" to "FORCE_BLOCKED",
        "platform" to "android",
        "currentVersion" to current,
        "minVersion" to minVersion,
        "installerSource" to installerSource,
        "reason" to "BELOW_MIN_VERSION",
        "storeUrl" to "https://play.google.com/store/apps/details?id=$pkgId"
      ))
      return
    }

    // From Play => start in-app update if available/allowed
    val mgr = appUpdateManager ?: AppUpdateManagerFactory.create(act)
    val updateType = if (mode == "flexible") AppUpdateType.FLEXIBLE else AppUpdateType.IMMEDIATE

    mgr.appUpdateInfo
      .addOnSuccessListener { info ->
        val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
        val allowed = info.isUpdateTypeAllowed(updateType)

        if (available && allowed) {
          try {
            mgr.startUpdateFlowForResult(info, updateType, act, REQ_CODE_UPDATE)
            result.success(mapOf(
              "action" to "UPDATE_STARTED",
              "platform" to "android",
              "currentVersion" to current,
              "minVersion" to minVersion,
              "installerSource" to installerSource,
              "reason" to "BELOW_MIN_VERSION"
            ))
          } catch (e: Exception) {
            result.success(mapOf(
              "action" to "OPEN_STORE",
              "platform" to "android",
              "currentVersion" to current,
              "minVersion" to minVersion,
              "installerSource" to installerSource,
              "reason" to ("START_UPDATE_FAILED: " + (e.message ?: "unknown")),
              "storeUrl" to "https://play.google.com/store/apps/details?id=$pkgId"
            ))
          }
        } else {
          result.success(mapOf(
            "action" to "OPEN_STORE",
            "platform" to "android",
            "currentVersion" to current,
            "minVersion" to minVersion,
            "installerSource" to installerSource,
            "reason" to if (!available) "UPDATE_NOT_AVAILABLE" else "UPDATE_NOT_ALLOWED",
            "storeUrl" to "https://play.google.com/store/apps/details?id=$pkgId"
          ))
        }
      }
      .addOnFailureListener { e ->
        result.success(mapOf(
          "action" to "OPEN_STORE",
          "platform" to "android",
          "currentVersion" to current,
          "minVersion" to minVersion,
          "installerSource" to installerSource,
          "reason" to ("PLAY_CORE_ERROR: " + (e.message ?: "unknown")),
          "storeUrl" to "https://play.google.com/store/apps/details?id=$pkgId"
        ))
      }
  }

  private fun openPlayStore(pkg: String) {
    val act = activity ?: return
    val market = Uri.parse("market://details?id=$pkg")
    val i = Intent(Intent.ACTION_VIEW, market).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try { act.startActivity(i) }
    catch (_: Exception) {
      act.startActivity(
        Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg"))
          .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      )
    }
  }

  private fun getCurrentVersionName(act: Activity): String {
    return try {
      val pm: PackageManager = act.packageManager
      val pInfo = pm.getPackageInfo(act.packageName, 0)
      pInfo.versionName ?: "0.0.0"
    } catch (_: Exception) {
      "0.0.0"
    }
  }

  private fun getInstallerSource(act: Activity, pkg: String): String {
    return try {
      val pm = act.packageManager
      val installer = if (android.os.Build.VERSION.SDK_INT >= 30) {
        pm.getInstallSourceInfo(pkg).installingPackageName
      } else {
        pm.getInstallerPackageName(pkg)
      } ?: ""

      when (installer) {
        "com.android.vending" -> "play_store"
        "", "null" -> "sideload"
        else -> "other"
      }
    } catch (_: Exception) {
      "unknown"
    }
  }

  // returns true if current < min
  private fun isVersionLower(current: String, min: String): Boolean {
    fun parse(v: String): List<Int> = v.split(".").map { it.trim().toIntOrNull() ?: 0 }
    val a = parse(current)
    val b = parse(min)
    val n = maxOf(a.size, b.size)
    for (i in 0 until n) {
      val ai = if (i < a.size) a[i] else 0
      val bi = if (i < b.size) b[i] else 0
      if (ai < bi) return true
      if (ai > bi) return false
    }
    return false
  }
}
