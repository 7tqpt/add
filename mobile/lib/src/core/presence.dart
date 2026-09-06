import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/api.dart';

/// الحضور: من في التطبيق الآن، ومتى كان فيه آخرَ مرّة.
///
/// **والعمودُ كان موجوداً ولا أحدَ يكتبه.** `app_users.last_seen_at` معرَّفٌ في
/// المخطَّط منذ أوّل يوم، وتقرؤه اللوحةُ في ثلاثة مواضع — «آخر ظهور» في صفحة
/// المستخدم، وعمودُها في القائمة، واستهدافُ البثّ بـ«نشِط»/«غير نشِط». وكان
/// فارغاً دائماً، فحملةٌ إلى «غير النشطين» كانت تذهب إلى الجميع. فهذا الملف
/// يملؤه.
///
/// ── ولماذا نبضةٌ لا قناةُ حضور ──
///
/// قناةُ Realtime تعرف من هو داخلُ التطبيق **هذه اللحظة**، وتنسى من خرج. وأكثرُ
/// ما يُقرأ في الشاشة ليس ذلك بل «آخر ظهور منذ ساعتين» — وهو ما لا تعرفه
/// القناة. والنبضةُ تعرف الاثنين، وتملأ عمودَ اللوحة معهما.
class Presence {
  Presence._();

  /// كم بين نبضةٍ وأخرى والتطبيقُ أمام صاحبه.
  static const beat = Duration(minutes: 1);

  /// المهلةُ التي يُعدّ صاحبُها فيها «متّصلاً الآن».
  ///
  /// ضِعفُ النبضة لا مثلُها: نبضةٌ واحدةٌ تسقط في شبكةٍ متعثّرة — وهي حالُ
  /// الشبكة هنا — فلو ساوت المهلةُ النبضةَ لَومض «متّصل» و«غير متّصل» تناوباً
  /// أمام مستخدمٍ لم يغادر.
  static const window = Duration(minutes: 2);

  static Timer? _timer;
  static _Lifecycle? _lifecycle;

  /// هل تنبض الآن.
  ///
  /// موجودةٌ ليُقاس بها لا لتُقرأ في شاشة: العلّةُ الأصليّة أنّ العمودَ كان
  /// موجوداً ولا أحدَ يكتبه، وحذفُ `Presence.start()` من قشرةٍ يعيدها بلا أن
  /// يسقط اختبارٌ واحد. فهذه هي العروة التي يُمسك بها ذلك.
  static bool get running => _lifecycle != null;

  /// تُستدعى بعد تسجيل الدخول — من القشرة كما يُستدعى الدفع.
  ///
  /// ولا تُستدعى قبله: النبضةُ تكتب في صفِّ مستخدم، ولا صفَّ لمن لم يدخل.
  static void start() {
    if (_lifecycle != null) return;
    _lifecycle = _Lifecycle();
    WidgetsBinding.instance.addObserver(_lifecycle!);
    _resume();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    if (_lifecycle != null) {
      WidgetsBinding.instance.removeObserver(_lifecycle!);
      _lifecycle = null;
    }
  }

  static void _resume() {
    _timer?.cancel();
    ping();
    _timer = Timer.periodic(beat, (_) => ping());
  }

  static void _pause() {
    _timer?.cancel();
    _timer = null;
    // ونبضةٌ أخيرةٌ عند الخروج لا عند الدخول وحده: من أغلق التطبيق بعد
    // خمسين ثانيةً من آخر نبضةٍ يُقرأ ظهورُه متأخّراً بتلك الخمسين. وهذه
    // تجعل «آخر ظهور» لحظةَ المغادرة نفسَها.
    ping();
  }

  /// نبضةٌ واحدة. وفشلُها يمرّ صامتاً.
  ///
  /// **وهذا مقصود:** القاعدةُ تُحدَّث بيد صاحبها والتطبيقُ من متجر، فبينهما
  /// نافذةٌ تكون فيها الدالّةُ غيرَ موجودة. وفي تلك النافذة يجب أن يغيب سطرُ
  /// «متّصل الآن» لا أن تسقط شاشة.
  static Future<void> ping() => Api.touchPresence();

  /// هل يُعدّ صاحبُ هذا الظهور متّصلاً الآن.
  static bool isOnline(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    final since = DateTime.now().difference(lastSeen);
    // والسالبُ متّصل: ساعةُ الخادم قد تسبق ساعةَ الجهاز بثوانٍ، فيخرج الفرقُ
    // سالباً — وهو أقربُ ما يكون إلى «الآن»، لا أبعدُه.
    return since < window;
  }
}

class _Lifecycle extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        Presence._resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        Presence._pause();
      // و`inactive` تُترك: تقع على iOS عند كل شريط إشعارٍ يُسحب وكل مكالمةٍ
      // ترنّ، وصاحبُها لم يغادر التطبيق.
      case AppLifecycleState.inactive:
        break;
    }
  }
}
