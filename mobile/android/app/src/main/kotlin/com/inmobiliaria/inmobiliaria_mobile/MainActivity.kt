package com.inmobiliaria.inmobiliaria_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var waiting: (() -> Unit)? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "raices/avisos").setMethodCallHandler { call, result ->
            when (call.method) {
                "activate" -> {
                    if (waiting != null) { result.error("busy", "Ya hay una activación pendiente.", null); return@setMethodCallHandler }
                    val token = call.argument<String>("token")
                    val account = call.argument<String>("account")
                    if (token.isNullOrBlank() || account.isNullOrBlank()) { result.error("invalid", "Falta iniciar sesión.", null); return@setMethodCallHandler }
                    val activate = {
                        try {
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                result.error("permission", "Autoriza las notificaciones en Ajustes de Android.", null)
                            } else {
                                AvisosAndroid.enable(this, account, token)
                                Thread { AvisosAndroid.poll(applicationContext) }.start()
                                result.success(true)
                            }
                        } catch (_: Exception) { result.error("activation", "No se pudieron activar los avisos de Android.", null) }
                    }
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        waiting = activate
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 637)
                    } else activate()
                }
                "disable" -> { AvisosAndroid.disable(this); result.success(true) }
                "status" -> result.success(AvisosAndroid.enabled(this))
                "poll" -> Thread { val ok=AvisosAndroid.poll(applicationContext); runOnUiThread { result.success(ok) } }.start()
                else -> result.notImplemented()
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 637) { val action=waiting; waiting=null; action?.invoke() }
    }
}
