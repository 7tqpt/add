// صفُّ «افتح بالبصمة» في أبواب «حسابي».
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «اريد ايقون افتح بالبصمة تكون راس في حسابي»، ثمّ اختار الشكلَ (ج): صفٌّ
// بمفتاحٍ يُشغّل ويُطفئ في مكانه لا بابٌ يفتح شاشة. وكانت ثلاثَ ضغطاتٍ
// بعيدة: الإعدادات ← الخصوصية والأمان ← المفتاح.
//
// ── ولا يُسأل المفتاحُ عمّا يعرضه ───────────────────────────────────────────
//
// `Switch` يعرض ما يُمرَّر إليه، ودالّةٌ لا تكتب شيئاً تترك الشاشةَ كما هي
// وتُرضي العين. **فيُقاس ما وصل الخزنة** (`lockBiometricIsOn`) لا ما رُسم.
//
// ── وأخطرُ ما هنا: مفتاحٌ يَعِد بما لم يُختبَر ───────────────────────────────
//
// من رفع المفتاحَ ولم تُقرأ بصمتُه يجب أن يجده منخفضاً كما كان — ولو كُتب
// التفضيلُ بلا تجربةٍ لَوجد نفسه يومَ الحاجة أمام وعدٍ لم يُوفَّ به،
// وحسّاسٍ لا يفتح، وقفلٍ لا يعرف رمزَه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account.dart';

/// حسّاسٌ مركَّب — **لا حسّاسَ في `flutter test`**.
class _Fake implements Biometrics {
  _Fake({this.has = true});

  final bool has;

  /// أتطابق حين تُسأل — تُبدَّل في الاختبار نفسِه.
  bool ok = true;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async => ok;
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'p1'
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
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

const _toggle = ValueKey('account-biometric-toggle');

void main() {
  late _Fake fake;

  setUp(() {
    lockStorageOverride = {};
    fake = _Fake();
    biometricsOverride = fake;
  });

  tearDown(() async {
    await appLock.disable();
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  group('متى يُعرض الصفّ', () {
    testWidgets('**سابعاً — بين «طرق الدفع» و«الإعدادات»**', (tester) async {
      await appLock.enable('1234');
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      expect(find.byKey(_toggle), findsOneWidget);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(labels.indexOf('افتح بالبصمة'), labels.indexOf('طرق الدفع') + 1);
      expect(labels.indexOf('الإعدادات'), labels.indexOf('افتح بالبصمة') + 1);
    });

    testWidgets('**ولا يُعرض لجهازٍ لا يقرأ بصمة**', (tester) async {
      // مفتاحٌ يُرفع فلا يقع شيءٌ أسوأُ من مفتاحٍ غائب.
      biometricsOverride = _Fake(has: false);
      await appLock.enable('1234');
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      expect(find.byKey(_toggle), findsNothing);
      expect(find.text('افتح بالبصمة'), findsNothing);
    });

    testWidgets('**ولا يُعرض بلا قفلٍ مضبوط**', (tester) async {
      // البصمةُ بابٌ ثانٍ إلى القفل لا بديلٌ عنه، ومفتاحٌ بلا قفلٍ تحته
      // يَعِد بما لا يقع.
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      expect(find.byKey(_toggle), findsNothing);
    });
  });

  group('ما يصل الخزنة', () {
    testWidgets('**رفعُ المفتاح يكتب التفضيل**', (tester) async {
      await appLock.enable('1234');
      expect(await lockBiometricIsOn(), isFalse);

      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      await tester.tap(find.byKey(_toggle));
      await _settle(tester);

      // **وما وصل لا ما رُسم.**
      expect(await lockBiometricIsOn(), isTrue, reason: 'لم يصل الخزنةَ شيء');
      expect(appLock.biometricEnabled, isTrue);
    });

    testWidgets('**وبصمةٌ لم تُقرأ لا تُغيّر شيئاً**', (tester) async {
      await appLock.enable('1234');
      fake.ok = false;

      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      await tester.tap(find.byKey(_toggle));
      await _settle(tester);

      expect(await lockBiometricIsOn(), isFalse,
          reason: 'كُتب التفضيلُ ولم تُقرأ بصمة');
      expect(find.text('لم تُقرأ البصمة. لم يتغيّر شيء.'), findsOneWidget);
    });

    testWidgets('**وخفضُه يمحوه**', (tester) async {
      await appLock.enable('1234');
      await appLock.setBiometric(true);

      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
      await _settle(tester);

      await tester.tap(find.byKey(_toggle));
      await _settle(tester);

      expect(await lockBiometricIsOn(), isFalse);
    });
  });
}
