package ye.aras.aras

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.PowerManager
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannel()
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_BRIDGE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openChannelSettings" -> result.success(openChannelSettings())
                    "batteryUnrestricted" -> result.success(batteryUnrestricted())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * قناة الإشعارات.
     *
     * أندرويد ٨ فما فوق لا يعرض إشعاراً بلا قناة. وFCM ينشئ واحدةً من تلقاء
     * نفسه إن لم يجدها، لكنه يسمّيها «Miscellaneous» — فيجد المستخدم في
     * إعدادات جواله قناةً بهذا الاسم لا يعرف ما هي.
     *
     * **والنغمةُ تُضبط صراحةً ولا تُترك للافتراض.** المنشئُ يضع نغمةَ النظام
     * افتراضاً، لكنّ تركها بلا `AudioAttributes` يجعل بعضَ الأجهزة تشغّلها
     * على مجرى الوسائط لا مجرى الإشعارات — فتُكتم مع كتمِ الوسائط ويظنّ
     * صاحبُها أنّ الإشعارات صامتة.
     *
     * **ولا تُبدَّل قناةٌ بعد إنشائها.** أندرويد يثبّت نغمتَها وأهمّيتَها
     * عند الإنشاء ويتجاهل كلَّ تبديلٍ بعده — بتصميمٍ مقصود: الإعدادُ صار
     * ملكَ صاحب الجهاز لا التطبيق. فمن وصلته قناةٌ صامتةٌ مرّةً بقيت صامتةً
     * مهما صُلّحت الشيفرة.
     *
     * **فالعلاجُ الوحيد قناةٌ بمعرّفٍ جديد.** [LEGACY_CHANNEL] تُحذف،
     * و[R.string.notification_channel_id] هي الحيّة — وهي الوحيدة المذكورة
     * في `AndroidManifest.xml`.
     */
    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        // القناةُ القديمة تُحذف، وإلّا بقيت في إعدادات الجهاز قناتان باسمٍ
        // واحد: إحداهما صامتةٌ لا تُستعمل، ويُسكت المستخدمُ الحيّةَ ظنّاً.
        manager.deleteNotificationChannel(LEGACY_CHANNEL)

        val id = getString(R.string.notification_channel_id)
        if (manager.getNotificationChannel(id) != null) return

        val channel = NotificationChannel(
            id,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.setSound(
            Settings.System.DEFAULT_NOTIFICATION_URI,
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        channel.enableVibration(true)
        channel.enableLights(true)
        manager.createNotificationChannel(channel)
    }

    /**
     * يفتح شاشةَ القناة في إعدادات النظام — حيث تُختار النغمة.
     *
     * **وشاشةُ القناة لا شاشةُ التطبيق.** الثانية تعرض قائمةَ القنوات، ومن
     * أرادَ النغمةَ لزمه أن يعرف أيَّ قناةٍ يفتح ثمّ يجد «الصوت» داخلها —
     * ضغطتان زائدتان يضيع فيهما أكثرُ الناس. وهذه تُنزله على الشاشة التي
     * فيها النغمةُ والاهتزازُ مباشرةً.
     *
     * ويُعاد `false` إن تعذّر — فيسقط النداءُ إلى شاشة التطبيق في دارت.
     */
    private fun openChannelSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(
                        Settings.EXTRA_CHANNEL_ID,
                        getString(R.string.notification_channel_id),
                    ),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * هل التطبيقُ مُعفىً من تقييد البطّاريّة.
     *
     * **وهذا أشهرُ سببٍ لـ«لا يصلني إشعارٌ والتطبيق مغلق».** أندرويد يُدخل
     * التطبيقاتِ في سُبات Doze، وأجهزةُ إنفينكس وتكنو وشاومي وأوبو تزيد فوقه
     * قتلاً للخلفيّة أشدَّ من قياسيّ أندرويد. والمقيَّدُ لا يستيقظ لرسالة FCM
     * حتى تُفتح شاشتُه — فيصل الإشعارُ بعد ساعاتٍ أو لا يصل.
     *
     * ولا شيءَ في الشيفرة يعالج هذا: الإعفاءُ بيد صاحب الجهاز وحدَه.
     */
    private fun batteryUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(PowerManager::class.java) ?: return true
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * يفتح قائمةَ تقييد البطّاريّة في إعدادات النظام.
     *
     * **وقائمةٌ لا حوارُ طلب.** `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
     * يفتح حواراً بضغطةٍ واحدة — لكنّه يحتاج إذنَ
     * `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` في البيان، وسياسةُ Google Play
     * تسأل عنه وتردّ به تطبيقاتٍ كثيرة. وهذه القائمةُ لا تحتاج إذناً ولا
     * تعرّض النشرَ للردّ — والثمنُ ضغطتان يجد فيهما اسمَ التطبيق.
     */
    private fun openBatterySettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        const val CHANNEL_BRIDGE = "ye.aras.aras/notifications"

        /** القناةُ الأولى — أُنشئت بلا `AudioAttributes` فتُحذف. */
        const val LEGACY_CHANNEL = "farhati_default"
    }
}
