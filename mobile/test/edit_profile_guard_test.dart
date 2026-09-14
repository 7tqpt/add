// «تعديل بياناتي»: لا يُحفظ ما لم يتغيّر، ولا يُخرَج بما كُتب صمتاً.
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// **١) الزرُّ مطفأٌ حتى يتغيّر شيء.** كان حيّاً أبداً: يُفتح الملفُّ ولا
//    يُلمَس شيءٌ والزرُّ مضيءٌ يدعو، فيُضغط ويُرسَل طلبٌ إلى الخادم بلا سبب.
//
// **٢) والخروجُ يسأل قبل أن يمحو.** وهذا أخطرُها: الخسارةُ حقيقيّةٌ ولا
//    تُرى — يعدّل اسمَه، يصرفه شيء، يضغط رجوعاً، فيذهب ما كتب ولا يعلم.
//
// **٣) والخطأُ عند حقله لا في القاع.** «اكتب اسمك كاملاً» كان سطراً أحمرَ
//    فوق زرّ الحفظ وحقلُ الاسم سليمُ المظهر — وقد يكون السطرُ خارجَ الشاشة.
//
// **٤) والبريدُ سطرٌ واحدٌ وشرحُه مطويّ** — حقيقةٌ لا تُعدَّل لا تأخذ بطاقةً
//    كاملةً تزاحم ما جاء المستخدمُ ليلمسه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/edit_profile.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _user() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false
  ..phoneGate =
      const PhoneGate(required_: true, verified: true, phone: '770000000');

final _save = find.byKey(const ValueKey('save-profile'));
final _name = find.byType(TextField).first;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed != null;

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(EditProfileScreen(session: _user())));
  await _settle(tester);
}

void main() {
  setUp(demoResetProfile);

  group('**الحفظُ يعرف متى يُحفظ**', () {
    testWidgets('مطفأٌ ولم يتغيّر شيء', (tester) async {
      await _open(tester);

      expect(_saveEnabled(tester), isFalse,
          reason: 'الزرُّ حيٌّ ولم يُلمَس شيء');
      expect(find.text('تعديلٌ لم يُحفظ'), findsNothing);
    });

    testWidgets('**ويحيا بأوّل حرف**', (tester) async {
      await _open(tester);
      await tester.enterText(_name, 'أيمن محمد الشرعبي');
      await _settle(tester);

      expect(_saveEnabled(tester), isTrue);
      expect(find.text('تعديلٌ لم يُحفظ'), findsOneWidget,
          reason: 'لا شيءَ يقول إنّ في الشاشة ما لم يُحفظ');
    });

    testWidgets('**ويعود مطفأً إن رُدَّ النصُّ كما كان**', (tester) async {
      // **ولا يكفي «لُمس الحقل».** من كتب حرفاً ثمّ محاه لم يغيّر شيئاً،
      // وزرٌّ يبقى حيّاً بعدها يكذب.
      final was = demoProfile()!.fullName;
      await _open(tester);

      await tester.enterText(_name, '$was!');
      await _settle(tester);
      expect(_saveEnabled(tester), isTrue);

      await tester.enterText(_name, was);
      await _settle(tester);
      expect(_saveEnabled(tester), isFalse,
          reason: 'بقي الزرُّ حيّاً وقد عاد النصُّ كما كان');
    });
  });

  group('**والخروجُ يسأل قبل أن يمحو**', () {
    testWidgets('لا يُسأل من لم يغيّر شيئاً', (tester) async {
      await _open(tester);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await _settle(tester);

      expect(find.text('تخرج ولم تحفظ؟'), findsNothing,
          reason: 'سُئل من لا شيءَ عنده يضيع');
    });

    testWidgets('**ويُسأل من عدّل**', (tester) async {
      await _open(tester);
      await tester.enterText(_name, 'اسمٌ آخر');
      await _settle(tester);

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await _settle(tester);

      expect(find.text('تخرج ولم تحفظ؟'), findsOneWidget);
      expect(find.text('أكمل التعديل'), findsOneWidget);
      expect(find.text('اخرج بلا حفظ'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget,
          reason: 'خرجت الشاشةُ والسؤالُ مفتوح');
    });

    testWidgets('**و«أكمل التعديل» تُبقيه** — ولا يضيع ما كتب',
        (tester) async {
      await _open(tester);
      await tester.enterText(_name, 'اسمٌ آخر');
      await _settle(tester);

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await _settle(tester);
      await tester.tap(find.text('أكمل التعديل'));
      await _settle(tester);

      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('اسمٌ آخر'), findsOneWidget,
          reason: 'ضاع ما كتبه وقد قال «أكمل»');
    });
  });

  group('**والخطأُ عند حقله**', () {
    testWidgets('اسمٌ ناقصٌ يحمّر حقلَه', (tester) async {
      await _open(tester);
      await tester.enterText(_name, 'ع');
      await _settle(tester);
      await tester.tap(_save);
      await _settle(tester);

      // **ويُسأل الحقلُ نفسُه لا الشاشة:** نصٌّ موجودٌ في مكانٍ ما لا يقول
      // أيَّ حقلٍ يُصلح.
      final field = tester.widget<TextField>(_name);
      expect(field.decoration?.errorText, 'اكتب اسمك كاملاً.');
    });
  });

  group('**والرقمُ سطرٌ بزرِّ تعديل**', () {
    testWidgets('يُعرض ولا يُكتب في نموذج', (tester) async {
      await _open(tester);

      expect(find.byKey(const ValueKey('phone-row')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'رقم الجوال'), findsNothing);
    });

    testWidgets('**وضغطُه يفتح ورقةَ التبديل المشحونة**', (tester) async {
      // **ويُقاس ما فُتح لا وجودُ الزرّ:** زرٌّ لا يفتح شيئاً يمرّ على من
      // يسأل «أموجودٌ الزرّ؟».
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('phone-edit')));
      await _settle(tester);

      // **ويُسأل مفتاحُ الورقة المشحونة لا عنوانٌ رسمتُه أنا.** رسمتُ في
      // المقترح عنواناً «تعديل رقم الجوال»، وعنوانُها الحقيقيُّ «رقم
      // الجوال» — فلو قيس الرسمُ لَمرّ الاختبارُ على ورقةٍ لا وجودَ لها.
      expect(find.byKey(const ValueKey('phone-edit-field')), findsOneWidget,
          reason: 'فُتحت الورقةُ بلا حقلٍ يُكتب فيه — أو لم تُفتح');
    });

    testWidgets('**ولا يُحرَّك زرُّ الحفظ بفتح الورقة**', (tester) async {
      // الرقمُ يُحفظ في ورقته لا مع الاسم، فلا يجعل النموذجَ «معدَّلاً».
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('phone-edit')));
      await _settle(tester);

      // **وتُغلق الورقةُ بالملّاح لا بنقرةٍ على الحاجب.** النقرةُ تُسقطها
      // وحقلُها ما زال يحمل التركيز، فيتعثّر نظامُ التركيز ويسقط
      // **الاختبارُ التالي** بتأكيدٍ من إطار العمل لا علاقةَ له بما يُقاس.
      tester.binding.focusManager.primaryFocus?.unfocus();
      await _settle(tester);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await _settle(tester);

      expect(_saveEnabled(tester), isFalse);
    });
  });

  group('**والبريدُ سطرٌ وشرحُه مطويّ**', () {
    testWidgets('يُعرض ولا يُثقل', (tester) async {
      await _open(tester);

      expect(find.byKey(const ValueKey('email-row')), findsOneWidget);
      expect(find.text('demo@example.com'), findsOneWidget);
      expect(find.textContaining('به تدخل إلى حسابك'), findsNothing,
          reason: 'الشرحُ الطويلُ معروضٌ ولم يُسأل عنه');
    });

    testWidgets('**ويُفتح لمن سأل «لماذا؟»**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('email-why')));
      await _settle(tester);

      expect(find.textContaining('به تدخل إلى حسابك'), findsOneWidget,
          reason: 'الشرحُ حُذف لا طُوي');
    });
  });
}
