// **العودةُ من نافذةٍ فتحها التطبيقُ نفسُه ليست غياباً — ولها حدٌّ.**
//
// ── العطلُ الذي أوجب هذا الملفّ ─────────────────────────────────────────────
//
// قال صاحبُ المنصّة: «عند ما أجي أغيّر صورة يخرجني التطبيق ولم يتغيّر شيء».
//
// **والسببُ قفلُ التطبيق لا الصورةُ ولا الرفع.** المعرضُ نافذةُ نظامٍ خارج
// التطبيق: يهبط التطبيقُ إلى الخلفيّة فيُسجَّل غياباً، ويعود فيُقفل — فيبدّل
// `RootScreen` الشجرةَ كلَّها بشاشة الرمز، **وتُهدَم معها الشاشةُ المنتظِرةُ
// للصورة**، فيرجع انتظارُها إلى حالةٍ `mounted == false` قبل أن يرفع شيئاً.
// فأثران لسببٍ واحد.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يكفي أن يُقاس أنّ الرحلةَ تُعفى.** إعفاءٌ بلا حدٍّ يُلغي القفلَ من
// حيث لا يُرى: تُفتح رحلةٌ فلا تُغلق، فلا يُقفل التطبيقُ بعدها أبداً. فيُقاس
// الطرفان معاً:
//
//   ١) **العودةُ من رحلةٍ لا تُقفل** — وهو الإصلاح.
//   ٢) **والعودةُ من غيابٍ عاديٍّ تُقفل** — وهو أنّ الإصلاح لم يقتل القفل.
//   ٣) **ورحلةٌ طالت فوق الحدّ تُقفل** — وهو اختيارُ صاحب المنصّة: من ترك
//      المعرضَ وذهب لا يعود إلى حسابٍ مفتوح.
//   ٤) **ورحلةٌ سقطت بخطأ تنتهي كما تنتهي الناجحة** — وإلّا بقي القفلُ
//      معطَّلاً بخطأٍ عابر.
//
// **والقياسُ على الشجرة لا على الرايات وحدَها:** يُبنى `RootScreen` المشحون
// وتُدفع دورةُ الحياة كما يدفعها النظام، ويُسأل: أظهرت شاشةُ الرمز؟
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/root.dart';

/// حسّاسٌ يرفض — **وإلّا فتح القفلَ بنفسه فلم يُقَس شيء.**
class _Sensor implements Biometrics {
  const _Sensor();
  @override
  Future<bool> available() async => false;
  @override
  Future<bool> authenticate() async => false;
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void main() {
  late DateTime now;

  setUp(() {
    lockStorageOverride = {};
    biometricsOverride = const _Sensor();
    now = DateTime(2026, 9, 17, 10);
    lockClock = () => now;
    // **والنسخةُ الواحدةُ تُنظَّف بين الاختبارات.** `awayFromApp` تعمل على
    // `appLock` العامّ — ورحلةٌ يتركها اختبارٌ مفتوحةً تُعفي الذي بعده،
    // فيمرّ على قفلٍ لا يقفل.
    while (appLock.excursionsOpen > 0) {
      appLock.endExcursion();
    }
  });
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
    lockClock = DateTime.now;
  });

  Future<AppLock> opened() async {
    await lockSetPin('1234');
    await appLock.boot();
    await appLock.unlock('1234');
    return appLock;
  }

  group('**الرايةُ نفسُها**', () {
    test('١) العودةُ من رحلةٍ لا تُقفل', () async {
      final lock = await opened();
      lock.beginExcursion();
      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isFalse,
          reason: 'قُفل وهو عائدٌ من نافذةٍ فتحها التطبيقُ نفسُه');
      lock.endExcursion();
    });

    test('٢) **والعودةُ من غيابٍ عاديٍّ تُقفل**', () async {
      // **وهذا يمنع أن يصير الإصلاحُ إلغاءً للقفل.** لولاه لَمرّ كسرٌ
      // يُعفي كلَّ عودةٍ كانت أو لم تكن رحلة.
      final lock = await opened();
      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'غاب فعلاً ولم يُقفل');
    });

    test('٣) **ورحلةٌ طالت فوق الحدّ تُقفل**', () async {
      final lock = await opened();
      lock.beginExcursion();
      lock.onLeave();
      now = now.add(lockExcursionGrace + const Duration(seconds: 1));
      lock.onReturn();
      expect(lock.locked, isTrue,
          reason: 'ترك المعرضَ وذهب، فعاد إلى حسابٍ مفتوح');
    });

    test('وما دون الحدّ لا يُقفل', () async {
      final lock = await opened();
      lock.beginExcursion();
      lock.onLeave();
      now = now.add(lockExcursionGrace - const Duration(seconds: 1));
      lock.onReturn();
      expect(lock.locked, isFalse);
      lock.endExcursion();
    });

    test('**ورحلةٌ نُسيت لا تُعفي إلى الأبد**', () async {
      // تُهدَم الشاشةُ قبل أن تُنهيَ رحلتَها، فيبقى العدّادُ مرفوعاً. ولولا
      // النسيانُ بعد المهلة لَصار القفلُ قفلاً لا يقفل.
      final lock = await opened();
      lock.beginExcursion(); // ولا `endExcursion` — كما لو هُدمت الشاشة
      now = now.add(lockExcursionGrace + const Duration(seconds: 1));

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue);

      // ثمّ يفتح قفلَه ويغيب غياباً عاديّاً — فيُقفل كما يُقفل كلُّ غياب.
      await lock.unlock('1234');
      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'بقيت الرحلةُ المنسيّةُ تُعفي');
    });

    test('**ورحلةٌ مهجورةٌ لا تسمّم التي بعدها**', () async {
      // **وهذا عيبٌ كشفه ضابطٌ سالبٌ لم يسقط، لا قراءةٌ عابرة.** كان بدءُ
      // الرحلة `_excursionAt ??= now` — فترثُ الجديدةُ لحظةَ بدء القديمة
      // المهجورة فتُولد منقضية، فيعود العطلُ بعينه.
      final lock = await opened();
      lock.beginExcursion(); // رحلةٌ هُجرت: لا `endExcursion` لها
      now = now.add(lockExcursionGrace + const Duration(minutes: 5));

      // ثمّ يفتح معرضَه من جديد — وهذه رحلةٌ جديدةٌ لم تطُل.
      lock.beginExcursion();
      lock.onLeave();
      lock.onReturn();

      expect(lock.locked, isFalse,
          reason: 'ورثت الرحلةُ الجديدةُ انقضاءَ القديمة، فعاد العطل');
      lock.endExcursion();
    });

    test('**ورحلتان متداخلتان: نهايةُ الأولى لا تكشف الثانية**', () async {
      final lock = await opened();
      lock.beginExcursion();
      lock.beginExcursion();
      lock.endExcursion();

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isFalse, reason: 'كُشفت رحلةٌ ما زالت مفتوحة');
      lock.endExcursion();
    });
  });

  group('**و`awayFromApp` تُنهي ما تبدأ**', () {
    test('تنتهي الرحلةُ بنجاح العمل', () async {
      final lock = await opened();
      await awayFromApp(() async => 1);

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'بقيت الرحلةُ مفتوحةً بعد تمامها');
    });

    test('**وبسقوطه كذلك**', () async {
      // **و`finally` لا `then`.** رحلةٌ تسقط بخطأ يجب أن تنتهي كما تنتهي
      // الناجحة، وإلّا عطّل خطأٌ عابرٌ القفلَ حتى تنقضي مهلتُه.
      final lock = await opened();
      await expectLater(
        awayFromApp(() async => throw StateError('سقط المنتقي')),
        throwsStateError,
      );

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'خطأٌ عابرٌ عطّل القفل');
    });
  });

  group('**وعلى الشجرة لا على الرايات وحدَها**', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    Future<void> cycle(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
    }

    testWidgets('رحلةٌ إلى المعرض لا تُلقيه على شاشة الرمز', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final lock = await opened();
      await tester.pumpWidget(
        _wrap(RootScreen(session: _session(), lock: lock)),
      );
      await settle(tester);

      lock.beginExcursion();
      await cycle(tester);

      expect(find.byType(LockScreen), findsNothing,
          reason: 'عاد العطلُ: يُلقى على شاشة الرمز وهو ينتقي صورة');
      lock.endExcursion();
    });

    testWidgets('**وغيابٌ عاديٌّ يُلقيه عليها**', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final lock = await opened();
      await tester.pumpWidget(
        _wrap(RootScreen(session: _session(), lock: lock)),
      );
      await settle(tester);

      await cycle(tester);

      expect(find.byType(LockScreen), findsOneWidget,
          reason: 'غاب فعلاً ولم يُطالَب برمزه — صار القفلُ زينة');
    });
  });
}
