import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/app_lock.dart';
import '../core/session.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'welcome.dart';
import 'lock.dart';
import 'update_prompt.dart';
import 'onboarding.dart';
import 'recover_password.dart';
import 'verify_phone.dart';
import 'customer_shell.dart';
import 'provider_shell.dart';

/// بوّابة الإقلاع: جلسة، ثم ملف، ثم دور.
///
/// الترتيب مقصود — من لا جلسة له لا معنى لسؤاله عن دوره، ومن لا ملف له لا
/// يستطيع الحجز ولو كان مسجَّل الدخول.
class RootScreen extends StatefulWidget {
  const RootScreen({
    super.key,
    required this.session,
    this.lock,
    this.update,
  });
  final Session session;

  /// حارسُ القفل — يُترك فارغاً في الاختبارات التي لا تعنيها.
  final AppLock? lock;

  /// حارسُ التحديث — يُترك فارغاً كذلك.
  final UpdateGate? update;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  /// حالُ الجلسة في آخر مرّةٍ نُظر فيها — يُقارَن بها لالتقاط **التبدّل**.
  ///
  /// **وتُملأ في `initState` لا بـ`late`.** الأخيرةُ تؤجّل الحساب إلى أوّل
  /// قراءة، وأوّلُ قراءةٍ تقع **داخل** المستمع — أي بعد أن تكون الجلسة قد
  /// فُتحت. فتُقرأ «مفتوحة» وتُقارَن بـ«مفتوحة» فلا يُرى تبدّلٌ أصلاً،
  /// ويبقى العطبُ كما هو. كُتبت `late` أوّلاً فسقط الاختبار، فبانت.
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    // **مراقبةُ دورة الحياة هنا لا في شاشة.** المغادرةُ والعودةُ تقعان
    // للتطبيق كلِّه، وشاشةٌ تراقبهما تفوتها الحالُ وهي ليست في المقدّمة.
    WidgetsBinding.instance.addObserver(this);
    _signedIn = widget.session.signedIn;
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// **تُطوى الشاشاتُ المكدّسة حين تتبدّل الجلسة.**
  ///
  /// هذه البوّابة تبدّل ما تعرضه بحسب الجلسة، لكنّها تبدّله **تحت** ما كُدِّس
  /// فوقها. وشاشةُ الدخول مكدَّسةٌ فوقها منذ صارت البدايةُ «ابدأ رحلتك» ثم
  /// «اختر نوع الحساب»: فكان المستخدم يكتب بريده وكلمته، **وينجح دخوله
  /// فعلاً**، ثمّ تبقى شاشة الدخول في وجهه ولا يقع شيء أمامه — والتطبيق
  /// مفتوحٌ خلفها لا يراه.
  ///
  /// والخروجُ مثلُه: من ضغط «خروج» وهو في شاشةٍ مكدَّسة كانت تبقى أمامه
  /// وحسابُه قد أُغلق تحتها.
  ///
  /// وطيُّها هنا لا في شاشة الدخول: الطريق إليها ثلاثةٌ اليوم وقد تصير
  /// أربعةً غداً، وحارسٌ في كلٍّ منها يُنسى واحدُه. وهذه تلتقط التبدّل نفسه
  /// أيّاً كان مصدره.
  void _onSessionChanged() {
    final now = widget.session.signedIn;
    if (now == _signedIn) return;
    _signedIn = now;

    // بعد الإطار لا داخله: الملاحة أثناء البناء ممنوعة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      // **واستعادةُ الكلمة تُستثنى — وهي الاستثناءُ الوحيد.**
      //
      // `verifyOTP(type: recovery)` **يفتح الجلسة** قبل أن تُكتب الكلمةُ
      // الجديدة بحرف. فطيٌّ بلا استثناءٍ يلقي صاحبَها في التطبيق وهو لم
      // يضع كلمتَه بعد — فيعود عند أوّل خروجٍ إلى البابِ نفسِه لا يعرف
      // كلمتَه، وهكذا أبداً. وهو ما كان يقع.
      //
      // وشاشةُ الاستعادة تطوي نفسَها حين تُحفظ الكلمة.
      if (nav.canPop()) {
        nav.popUntil(
          (route) => route.isFirst || route.settings.name == recoverRouteName,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = widget.lock;
    if (lock == null) return;
    // **والمغادرةُ تُسجَّل والعودةُ تُقارَن.** التطبيق قد يُقتل في الخلفيّة
    // فلا يعمل فيه مؤقّت — والذي يبقى هو لحظةُ آخر استعمال.
    if (state == AppLifecycleState.resumed) {
      lock.onReturn();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock.onLeave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    if (update == null) return _locked(context);

    // **والتحديثُ الإجباريُّ فوق القفل وفوق الدخول جميعاً.** من كان على نسخةٍ
    // لا تعمل مع الخدمة لا ينفعه أن يفتح قفله ولا أن يسجّل دخوله — النداءُ
    // نفسُه هو المكسور. ومن لم يسجّل بعدُ أحوجُ الناس إليه: نسختُه قد تكون
    // عاجزةً عن تسجيله أصلاً.
    return ListenableBuilder(
      listenable: update,
      builder: (context, child) {
        final forced = update.forced;
        if (forced != null) return ForcedUpdateScreen(release: forced);

        final banner = update.banner;
        if (banner == null) return child!;
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: UpdateBanner(release: banner, onDismiss: update.dismiss),
            ),
            Expanded(child: child!),
          ],
        );
      },
      child: _locked(context),
    );
  }

  /// طبقةُ القفل — تحت التحديث وفوق كلّ ما عداه.
  Widget _locked(BuildContext context) {
    final session = widget.session;
    final lock = widget.lock;

    // **والقفلُ فوق كلّ شيءٍ إلّا الدخول.** من ليس داخلاً لا معنى لقفله —
    // وشاشةُ الترحيب ليس فيها ما يُخفى.
    if (lock != null && session.signedIn) {
      return ListenableBuilder(
        listenable: lock,
        builder: (context, child) {
          // **وبابُ الضبط قبل بابِ الفتح.** من لم يضبط قفلاً لا يُطالَب
          // برمزٍ لا يملكه — يُطالَب بأن يضبطه. وهو قرارُ صاحب المنصّة:
          // يُفرض القفلُ فورَ الدخول، ولا تُفتح الشاشاتُ قبله.
          //
          // **ويشمل من هم داخلون اليومَ** بلا قفل: الرايةُ تُقرأ من الخزنة
          // عند الإقلاع، فيرون البابَ عند أوّل فتحةٍ بعد التحديث.
          if (!lock.enabled) {
            return LockGateScreen(lock: lock, onSignOut: session.signOut);
          }
          return lock.locked
              ? LockScreen(lock: lock, onSignOut: session.signOut)
              : child!;
        },
        child: _body(context),
      );
    }
    return _body(context);
  }

  Widget _body(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loading) {
          return const BootScreen();
        }
        // شاشةُ الترحيب لمن لا جلسة له وحده — ومن سجّل مرّةً يفتح التطبيق
        // على شاشته مباشرةً. وشاشةُ ترحيبٍ تسبق كلَّ فتحةٍ عائقٌ يوميٌّ لا
        // مقدّمة.
        if (!session.signedIn) return WelcomeScreen(session: session);
        // قبل شاشة الإكمال: من تعذّرت قراءة هويته لعطبٍ في القاعدة ليس
        // «مستخدماً بلا ملف»، وسَوقُه إلى الإكمال يُخفي السبب ويُفشل الحفظ.
        if (session.identityError != null) {
          final offline = session.identityErrorCode == offlineCode;
          final code = session.identityErrorCode;
          final drift = session.clockDrift;
          return Scaffold(
            appBar: AppBar(
              title: Text(offline ? tr('لا يوجد اتصال') : tr('فرحتي')),
              // **ولا زرَّ خروجٍ لمن انقطعت شبكتُه.** الخروجُ يمحو الجلسة،
              // والدخولُ من جديدٍ يحتاج شبكةً. فمن ضغطه وهو مقطوعٌ حبس
              // نفسَه خارجَ التطبيق حتى تعود الشبكة — وقد كان داخلَه قبل
              // ثانية. وهو زرٌّ يُضغط فعلاً هنا: الشاشةُ تقول «تعذّر» فيظنّه
              // مخرجاً.
              actions: offline
                  ? null
                  : [
                      TextButton(
                        onPressed: session.signOut,
                        child: Text(tr('خروج')),
                      ),
                    ],
            ),
            // **ولا نصَّ تقنيٌّ في وجه العميل ولا مطويّاً** — اختار صاحبُ
            // المنصّة (ب) بعد أن رأى عميلٌ «إن كنت لم تُطبّق ملفات مجلّد
            // supabase/…» ورمزَ PGRST303. والعطبُ يبقى في
            // `session.identityError` لمن يقرؤه من الشيفرة.
            body: offline
                ? ErrorBlock(message: offlineMessage, onRetry: session.refreshIdentity)
                : QuietError(
                    title: identityTitle(code, drift),
                    message: identityHint(code, drift),
                    icon: _clockIsOff(code, drift)
                        ? Icons.schedule_rounded
                        : Icons.sync_rounded,
                    onRetry: session.refreshIdentity,
                  ),
          );
        }
        if (session.needsProfile) return OnboardingScreen(session: session);
        // **وحاجزُ الرقم بعد الملفّ وقبل التطبيق.** قرّر صاحبُ المنصّة أنّ من
        // لم يؤكّد رقمه لا يرى التطبيق: الرقمُ هو ما يُتواصل به في كلّ حجز.
        //
        // وقبله الملفُّ لا بعده: الرقمُ يُكتب في «أكمل ملفك»، فسؤالُ من لا
        // ملفَّ له عن تأكيد رقمٍ لم يكتبه سؤالٌ عن لا شيء.
        //
        // وبعده الدورُ: العميلُ والمزوّدُ كلاهما يُسأل — ومزوّدٌ لا يُوصَل
        // إليه أسوأُ من عميل.
        if (session.needsPhoneVerification) {
          return VerifyPhoneScreen(session: session);
        }
        return session.asProvider
            ? ProviderShell(session: session)
            : CustomerShell(session: session);
      },
    );
  }
}

/// أساعةُ الجوال نفسِه هي السبب؟ — رمزُ «المستقبل» **وفرقٌ مقيسٌ** يُذكر.
///
/// فإن لم يُقَس فرقٌ فالعطبُ من ساعة الخادم، وليس على العميل فيه شيء.
bool _clockIsOff(String? code, Duration? drift) =>
    code == jwtIssuedAtFuture && clockSkewLabel(drift) != null;

/// عنوانُ الشاشة حين تتعذّر قراءةُ الحساب.
String identityTitle(String? code, [Duration? drift]) =>
    _clockIsOff(code, drift) ? tr('ساعة جوالك غير مضبوطة') : tr('تعذّر فتح حسابك الآن');

/// ما يُقال للعميل عن العطب — **جملةٌ يفهمها ويفعل بها، لا تشخيصُ مطوّر**.
///
/// كانت هنا نصوصٌ لصاحب المشروع وقتَ إعداده («إن كنت لم تُطبّق ملفات مجلّد
/// supabase/…»، «تأكّد من تطبيق policies.sql»)، فوقعت إحداها على عميلٍ
/// حقيقيّ حين جاءه عطبُ ساعةٍ مؤقّتٌ من الخادم. والعميلُ لا يملك المجلّد ولا
/// يعرفه — فلا يُقال له إلّا ما يخصّه.
String identityHint(String? code, [Duration? drift]) => switch (code) {
  // **ولا شبكةَ أصلاً.** والنصُّ هنا هو `offlineMessage` بعينه لتعرفه
  // `ErrorBlock` فتعرض وجهَ الانقطاع: رمزُ واي‑فاي مشطوبٌ وسطران.
  offlineCode => offlineMessage,
  // ساعةُ جواله هو متقدّمةٌ أو متأخّرة بقدرٍ مقيس — وهذا وحده يصلحه هو.
  jwtIssuedAtFuture when _clockIsOff(code, drift) =>
    trf('{0}\nفعّل «الوقت التلقائي» من إعدادات جوالك، ثم أعد المحاولة.',
        [clockSkewLabel(drift)!.replaceAll('**', '')]),
  // وكلُّ ما سواه — ومنه عطبُ ساعة الخادم بعد أن نفدت المحاولاتُ الصامتة.
  _ => tr('انقطاعٌ مؤقّتٌ من جهتنا، وبياناتك محفوظة.\nأعد المحاولة بعد لحظات.'),
};
