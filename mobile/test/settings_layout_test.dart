// ترتيبُ «الإعدادات» — أربعةُ فروقٍ اختارها صاحبُ المنصّة بالصورة.
//
// **وبطاقةٌ واحدةٌ للعنوان الواحد.** كانت «نغمة الإشعار» بطاقةً ثانيةً تحت
// عنوان «الإشعارات»، فتُقرأ قسماً بلا اسم — والعينُ تعدّ البطاقةَ قسماً قبل
// أن تقرأ عنوانه.
//
// ── ولماذا يُقرأ المصدرُ في أحدها ───────────────────────────────────────────
//
// بندُ «شارك التطبيق» **يغيب من نفسه في وضع العرض** لأنّ `SHARE_URL` فارغةٌ
// فيه. فاختبارٌ يقول «لا أجده في الشجرة» يمرّ سواءٌ حُذف أم لم يُحذف — وهو
// ضمانةٌ كاذبة. فيُسأل المصدرُ نفسُه: أفيه نداءٌ للبند؟
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_version.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/ui/kit.dart';

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

/// **ولوحٌ طويلٌ لا نافذةُ الاختبار.**
///
/// `ListView` لا يبني ما تحت الطيّة أصلاً، ونافذةُ الاختبار ٨٠٠×٦٠٠ —
/// فبطاقةُ «عن التطبيق» لا وجودَ لها في الشجرة، ويُقرأ غيابُها عطباً وهو
/// ضِيقُ نافذة.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

/// **بطاقةُ العنصر** — يُعرف بها أنّ صفّين في بطاقةٍ واحدةٍ أم في اثنتين.
Element _card(WidgetTester tester, String text) {
  final card = find.ancestor(
    of: find.text(text, skipOffstage: false),
    matching: find.byType(AppCard),
  );
  expect(card, findsOneWidget, reason: 'لا بطاقةَ حول «$text»');
  return tester.element(card);
}

void main() {
  testWidgets('**ولا بندَ «شارك التطبيق» في المصدر**', (tester) async {
    // **والمصدرُ لا الشجرة.** البندُ يغيب في وضع العرض على كلّ حال، فسؤالُ
    // الشجرة يمرّ ولو لم يُحذف شيء.
    final source =
        File('lib/src/screens/account_extras.dart').readAsStringSync();
    expect(source.contains('ShareAppTile'), isFalse,
        reason: 'البندُ ما زال يُنادى في الإعدادات');

    // وسقط معه ما لم يبقَ له مُنادٍ.
    final kit = File('lib/src/ui/share_button.dart').readAsStringSync();
    expect(kit.contains('ShareAppTile'), isFalse);
    final share = File('lib/src/core/share.dart').readAsStringSync();
    expect(share.contains('shareTextForApp'), isFalse);
  });

  testWidgets('**ونغمةُ الإشعار في بطاقة «الإشعارات» نفسِها**', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: Session())));
    await _settle(tester);

    // بطاقةٌ ثانيةٌ تحت العنوان نفسِه تُقرأ قسماً بلا اسم.
    expect(_card(tester, 'نغمة الإشعار'),
        same(_card(tester, 'إشعارات الحجوزات والرسائل')));
  });

  testWidgets('**واسمُ القسم اتّسع للبصمة**', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: Session())));
    await _settle(tester);

    expect(find.text('الخصوصية والأمان', skipOffstage: false), findsOneWidget);
    // والاسمُ القديم لا يسع البصمةَ التي دخلت عليه.
    expect(find.text('قفل التطبيق', skipOffstage: false), findsNothing);
  });

  testWidgets('**ورقمُ النسخة داخلَ بطاقة «عن التطبيق»**', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: Session())));
    await _settle(tester);

    // كان سطراً وحيداً في الفراغ تحت آخر بطاقة، فيُقرأ بقيّةً نُسيت.
    expect(_card(tester, appVersionLabel),
        same(_card(tester, 'سياسة الخصوصية')));
  });
}
