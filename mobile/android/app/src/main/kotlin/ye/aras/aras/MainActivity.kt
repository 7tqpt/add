package ye.aras.aras

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannel()
    }

    /**
     * قناة الإشعارات الافتراضية.
     *
     * أندرويد ٨ فما فوق لا يعرض إشعاراً بلا قناة. وFCM ينشئ واحدةً من تلقاء
     * نفسه إن لم يجدها، لكنه يسمّيها «Miscellaneous» — فيجد المستخدم في
     * إعدادات جواله قناةً بهذا الاسم لا يعرف ما هي، ولا يستطيع أن يُسكت نوعاً
     * دون نوع.
     *
     * وإنشاؤها هنا لا يحتاج حزمةً أصليةً ثالثة: عشرةُ أسطرٍ من Kotlin مقابل
     * اعتمادٍ كامل.
     */
    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val id = getString(R.string.default_notification_channel_id)
        if (manager.getNotificationChannel(id) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                id,
                getString(R.string.default_notification_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            )
        )
    }
}
