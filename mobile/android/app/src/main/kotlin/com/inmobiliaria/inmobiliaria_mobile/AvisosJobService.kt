package com.inmobiliaria.inmobiliaria_mobile

import android.app.*
import android.app.job.*
import android.content.*
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Consulta la bandeja sin Firebase. Android decide cuándo ejecutar la tarea periódica. */
object AvisosAndroid {
    const val JOB = 63730
    const val CHANNEL = "raices_avisos"
    private val guard = Any()
    private fun prefs(c: Context) = c.getSharedPreferences("raices_avisos", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val stored = store.getKey("raices_avisos_v1", null)
        if (stored is SecretKey) return stored
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("raices_avisos_v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val data = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(data, Base64.NO_WRAP)
    }
    private fun decrypt(value: String): String {
        val parts = value.split(":")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
        }
        return String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
    }
    fun enable(c: Context, account: String, token: String) = synchronized(guard) {
        val active = encrypt(JSONObject().put("account", account).put("token", token).toString())
        prefs(c).edit().putString("active", active).apply()
        val scheduler = c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        val info = JobInfo.Builder(JOB, ComponentName(c, AvisosJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPeriodic(15 * 60 * 1000L).setPersisted(true).build()
        check(scheduler.schedule(info) == JobScheduler.RESULT_SUCCESS) { "Android no permitió programar los avisos." }
    }
    fun disable(c: Context) = synchronized(guard) {
        prefs(c).edit().remove("active").apply()
        (c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB)
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }
    fun enabled(c: Context) = prefs(c).contains("active")
    fun poll(c: Context, stopped: () -> Boolean = { false }): Boolean {
        val snapshot = prefs(c).getString("active", null) ?: return true
        try {
            val data = JSONObject(decrypt(snapshot))
            val connection = URL("https://raices-backend-n1yy.onrender.com/api/notificaciones/avisos").openConnection() as javax.net.ssl.HttpsURLConnection
            connection.connectTimeout = 15000; connection.readTimeout = 20000
            connection.setRequestProperty("X-Avisos-Token", data.getString("token"))
            val rows = try {
                if (connection.responseCode != 200) return connection.responseCode in 400..499
                JSONObject(connection.inputStream.bufferedReader().use { it.readText() }).getJSONArray("notificaciones")
            } finally { connection.disconnect() }
            val account = data.getString("account")
            synchronized(guard) {
                if (stopped() || prefs(c).getString("active", null) != snapshot) return true
                var last = prefs(c).getInt("last:$account", 0)
                for (i in rows.length()-1 downTo 0) {
                    val row = rows.getJSONObject(i); val id = row.getInt("id")
                    if (id <= last) continue
                    show(c, id, row.optString("titulo", "Raíces"), row.optString("cuerpo", "Nueva notificación"))
                    last = id
                    prefs(c).edit().putInt("last:$account", last).apply()
                }
            }
            return true
        } catch (_: Exception) { return false }
    }
    fun show(c: Context, id: Int, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val manager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "Novedades de Raíces", NotificationManager.IMPORTANCE_DEFAULT))
        val intent = Intent(c, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val pending = PendingIntent.getActivity(c, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else Notification.Builder(c)
        manager.notify(id, builder.setSmallIcon(R.drawable.ic_aviso).setContentTitle(title.take(150)).setContentText(body.take(200))
            .setStyle(Notification.BigTextStyle().bigText(body.take(1000))).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(pending).setAutoCancel(true).build())
    }
}

class AvisosJobService : JobService() {
    @Volatile private var stopped = false
    override fun onStartJob(params: JobParameters): Boolean {
        stopped = false
        Thread {
            val success = AvisosAndroid.poll(applicationContext) { stopped }
            if (!stopped) jobFinished(params, !success)
        }.start()
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { stopped = true; return true }
}
