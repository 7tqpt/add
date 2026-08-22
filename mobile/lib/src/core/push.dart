import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/api.dart';

/// إشعارات الجوال.
///
/// **وهي اختياريةٌ عن قصد.** الدفع يحتاج مشروع Firebase وملفَّ
/// `google-services.json` يخرج منه، وهو ملكُ صاحب المنصّة لا المستودع. فلو
/// كان التطبيق يفترض وجوده لسقط عند كل من بناه بلا Firebase.
///
/// فهنا كلُّ نداءٍ محروس: إن لم تُهيَّأ Firebase بقي `active` على `false`،
/// وعمل التطبيق كما هو — الجرسُ يعمل والصندوق يمتلئ، ولا يصل إلى الجوال شيءٌ
/// وهو مغلق. ومتى وُضع الملف اشتغل الدفع بلا تعديل سطرٍ واحد.
///
/// **وما لا يفعله هذا الملف:** لا يعرض إشعاراً والتطبيق مفتوح. النظامُ يعرضه
/// وحده حين يكون التطبيق في الخلفية أو مغلقاً (حمولة `notification` في FCM)،
/// وأمّا وهو مفتوحٌ أمام المستخدم فالجرسُ في أعلى الشاشة أصدقُ دلالةً من
/// لافتةٍ تغطّي ما ينظر إليه. وعرضُها يحتاج حزمةً أصليةً ثالثة.
class Push {
  Push._();

  static bool _active = false;
  static String? _token;
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _opened;

  /// هل اشتغل الدفع فعلاً على هذا الجهاز.
  static bool get active => _active;

  /// رمز هذا الجهاز — يُحتاج عند الخروج لينساه الخادم.
  static String? get token => _token;

  /// تُستدعى بعد تسجيل الدخول.
  ///
  /// و`onOpened` تُستدعى حين يضغط المستخدم الإشعار من شريط النظام: تحمل
  /// `data` كما أرسلها الخادم — `conversation_id` أو `booking_id`.
  static Future<void> start({void Function(Map<String, dynamic> data)? onOpened}) async {
    if (_active) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // لا مشروع Firebase مربوطاً: هذه هي الحال الافتراضية، وليست عطباً.
      debugPrint('الدفع غير مفعّل (لا Firebase): $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // أندرويد ١٣ فما فوق يطلب إذناً صريحاً، وiOS كذلك. والرفض ليس فشلاً:
      // من رفض لا يصله شيء، ويبقى الجرس داخل التطبيق يعمل.
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await _register(token);

      // الرمز يتغيّر بلا إشعارٍ من النظام: عند إعادة تثبيت التطبيق، وعند
      // مسح بياناته، وأحياناً من تلقاء نفسه. فمن لا يستمع لتجديده يرسل إلى
      // رمزٍ ميّت ولا يعلم.
      _refresh = messaging.onTokenRefresh.listen(_register);

      if (onOpened != null) {
        _opened = FirebaseMessaging.onMessageOpenedApp.listen(
          (m) => onOpened(Map<String, dynamic>.from(m.data)),
        );
        // والتطبيق المغلق تماماً: الرسالة التي فتحته لا تمرّ بالمجرى أعلاه.
        final initial = await messaging.getInitialMessage();
        if (initial != null) onOpened(Map<String, dynamic>.from(initial.data));
      }

      _active = true;
    } catch (e) {
      debugPrint('تعذّر تشغيل الدفع: $e');
    }
  }

  static Future<void> _register(String token) async {
    _token = token;
    try {
      await Api.registerPushToken(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        model: defaultTargetPlatform.name,
      );
    } catch (e) {
      debugPrint('تعذّر تسجيل رمز الجهاز: $e');
    }
  }

  /// تُستدعى عند الخروج من الحساب.
  ///
  /// ونسيانُ الرمز ليس تنظيفاً: لو بقي مربوطاً بالحساب لوصلت إشعاراتُه إلى
  /// جهازٍ غادره صاحبه — وقد يكون جهازَ غيره.
  static Future<void> stop() async {
    final token = _token;
    _active = false;
    _token = null;
    await _refresh?.cancel();
    await _opened?.cancel();
    _refresh = null;
    _opened = null;
    if (token == null) return;
    try {
      await Api.forgetPushToken(token);
    } catch (e) {
      debugPrint('تعذّر نسيان رمز الجهاز: $e');
    }
  }
}
