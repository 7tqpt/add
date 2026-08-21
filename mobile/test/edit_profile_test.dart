// شاشة تعديل البيانات.
//
// وأهمّ ما يُثبَت هنا أن **البريد ليس حقلاً**: هو هويّة الدخول لا بيانَ ملف،
// وحقلٌ يغيّره في `app_users` وحده يُنتج حساباً يُعرض ببريدٍ ويدخل بآخر.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/edit_profile.dart';

Widget _wrap(Session s) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: EditProfileScreen(session: s)),
);

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  testWidgets('الحقول القابلة للتعديل ثلاثة', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'الاسم الكامل'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'رقم الجوال'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('والبريد يُعرض ولا يُكتب فيه', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    // لا حقلَ نصٍّ للبريد بحال — عرضٌ فقط، ومعه سببُ ذلك.
    expect(find.widgetWithText(TextField, 'البريد الإلكتروني'), findsNothing);
    expect(find.text('لا يُعدَّل هنا'), findsOneWidget);
    expect(find.text('demo@example.com'), findsOneWidget);
  });

  testWidgets('اسمٌ قصير يُرفض قبل أن يُرسل', (tester) async {
    // الحراسة في القاعدة أيضاً، لكن ردَّها يمرّ بالشبكة — ورفضٌ فوريّ أرحم.
    //
    // ونافذةٌ أطول من الافتراضية: زرّ الحفظ آخرُ القائمة، والقوائم في Flutter
    // تبني ما يظهر وحده — فلا يوجد الزرُّ في الشجرة أصلاً على ٦٠٠ بكسل.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'الاسم الكامل'), 'أ');
    // النصّ لا النوع: `FilledButton.icon` تُنتج نوعاً مشتقّاً، و`find.byType`
    // يطابق النوع الحرفيّ وحده فلا يجده.
    final save = find.text('حفظ التعديلات');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك كاملاً.'), findsOneWidget);
  });

  testWidgets('زرّ الكاميرا يفتح خيارَي الالتقاط والمعرض', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_camera));
    await tester.pumpAndSettle();
    expect(find.text('التقاط صورة'), findsOneWidget);
    expect(find.text('اختيار من المعرض'), findsOneWidget);
  });
}
