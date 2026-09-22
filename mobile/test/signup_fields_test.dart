// حقولُ التسجيل: العنوانُ فوقَ الصندوق، والصندوقُ فارغ.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «عند تسجيل حساب جديد، الاسم الكامل — في التكست، شيل النصّ الموجود».
// واختار (أ) من ثلاث: العنوانُ فوقَ الصندوق.
//
// ── والحقلُ كان فارغاً، والمرئيُّ عنوانُه ─────────────────────────────────
//
// `_name` يُنشأ فارغاً ولا يُكتب فيه شيء. والذي كان يُرى `labelText` قابعاً
// داخلَ الصندوق يطفو عند الكتابة — فيُقرأ نصّاً مكتوباً لمن لم يكتب بعد.
//
// ── ولا يُسأل الحقلُ عن إعداده، يُقاس أين رُسم عنوانُه ────────────────────
//
// «أفيه `floatingLabelBehavior.always`؟» سؤالٌ عن الشيفرة يُجاب بنعم وإن
// تبدّل ما يُرسم. **فيُقاس موضعُ العنوان من الصندوق**: إن كان في ثلثه
// الأعلى فهو فوقَه، وإن كان في وسطه فهو داخلَه.
//
// ── والمثالُ يُشال مع العنوان، وهذا هو المهمّ ──────────────────────────────
//
// `hintText` **لا يظهر ما دام العنوانُ قابعاً** في الصندوق. فلو طفا العنوانُ
// وبقي المثالُ لَظهر مكانَه — أي لَبقي في الصندوق نصٌّ بعد أن طُلب أن
// يُفرَّغ، ولَكان التبديلُ قد أبدل نصّاً بنصّ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/onboarding.dart';

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

Session _fresh() => Session()
  ..userId = 'u1'
  ..email = 'new@sdd.company'
  ..loading = false;

/// يفتح الشاشةَ ويتجاوز اختيارَ الصفة — فشاشةُ التسجيل خطوتان، ولا تظهر
/// بطاقةُ «أهلاً بك» إلّا بعد الأولى.
Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(OnboardingScreen(session: _fresh())));
  await tester.pumpAndSettle();
  await tester.tap(find.text('أنا عروس'));
  await tester.pumpAndSettle();
}

/// أين وقع عنوانُ الحقل من ارتفاع صندوقه: ‎٠‎ أعلاه و‎١‎ أسفلُه.
double _labelAt(WidgetTester tester, String label, Finder field) {
  final text = find.descendant(of: field, matching: find.text(label));
  expect(text, findsOneWidget, reason: 'لا عنوانَ «$label» في حقله');
  final box = tester.getRect(field);
  return (tester.getCenter(text).dy - box.top) / box.height;
}

void main() {
  group('حقولُ التسجيل', () {
    testWidgets('**العنوانُ فوقَ الصندوق لا في وسطه**', (tester) async {
      await _open(tester);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2), reason: 'عددُ الحقول تبدّل');

      for (final entry in {'الاسم الكامل': 0, 'رقم الجوال': 1}.entries) {
        final at = _labelAt(tester, entry.key, fields.at(entry.value));
        expect(at, lessThan(0.3),
            reason: '«${entry.key}»: العنوانُ عند ${at.toStringAsFixed(2)} من '
                'ارتفاع الصندوق — أي قابعٌ فيه لا فوقه');
      }
    });

    testWidgets('**والمحافظةُ على شكلهما — والثلاثةُ واحد**', (tester) async {
      // كانت هي وحدَها عنوانُها طافٍ، فصارت الثلاثةُ عليه. ولو عادت هي
      // لَافترق شكلُ البطاقة نصفين.
      await _open(tester);

      final at = _labelAt(tester, 'المحافظة',
          find.byType(DropdownButtonFormField<String>));
      expect(at, lessThan(0.3),
          reason: 'عنوانُ المحافظة قبع في صندوقه — فافترق شكلُ البطاقة');
    });

    testWidgets('**والصندوقُ فارغٌ لا مثالَ فيه**', (tester) async {
      // **وهذه هي التي تنكسر بصمت**: `hintText` لا يظهر ما دام العنوانُ
      // قابعاً، فإذا طفا العنوانُ ظهر المثالُ مكانَه — فيُبدَّل نصٌّ بنصّ
      // ويُقال «شِيل» وهو لم يُشَل.
      await _open(tester);

      expect(find.text('محمد الصنعاني'), findsNothing,
          reason: 'المثالُ ظهر في الصندوق بعد أن طفا العنوان');
      expect(find.text('+967 7XX XXX XXX'), findsNothing,
          reason: 'مثالُ الجوال ظهر في الصندوق');
    });

    testWidgets('**ولا يُكتب في الحقل شيءٌ لم يكتبه صاحبُه**', (tester) async {
      // ولا يُسأل الشكلُ عمّا فيه: يُسأل المتحكّمُ نفسُه.
      await _open(tester);

      final name = tester.widget<TextField>(find.byType(TextField).first);
      expect(name.controller?.text ?? '', isEmpty,
          reason: 'في حقل الاسم نصٌّ قبل أن يكتب صاحبُه');
    });
  });
}
