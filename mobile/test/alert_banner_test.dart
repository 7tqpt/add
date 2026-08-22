// شريطُ الإشعار الذي ينزل والتطبيق مفتوح.
//
// وما يُختبَر هنا هو **متى لا ينزل**: عند أوّل اشتراكٍ بإشعارٍ قديم، وعند
// إشعارٍ قُرئ. وشريطٌ ينزل بخبرٍ من أسبوع يجعل المستخدم يتجاهل ما بعده.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/alert_banner.dart';

AppNotification _n(String id, {bool read = false, Map<String, dynamic> data = const {}}) =>
    AppNotification(
      id: id,
      kind: NotificationKind.booking,
      title: 'قُبل حجزك $id',
      body: 'أكّدت قاعة التاج حجزك.',
      data: data,
      readAt: read ? DateTime.now().toIso8601String() : null,
      createdAt: DateTime.now().toIso8601String(),
    );

void main() {
  late StreamController<List<AppNotification>> source;
  late List<Map<String, dynamic>> opened;

  setUp(() {
    source = StreamController<List<AppNotification>>();
    opened = [];
  });
  tearDown(() => source.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
          child: AlertBanner(
            source: source.stream,
            onOpen: opened.add,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('الدفعةُ الأولى لا تُعرض', (tester) async {
    await pump(tester);
    source.add([_n('a')]);
    await tester.pumpAndSettle();
    expect(find.textContaining('قُبل حجزك'), findsNothing);
  });

  testWidgets('والواصلُ بعدها ينزل بعنوانه', (tester) async {
    await pump(tester);
    source.add([_n('a')]);
    await tester.pumpAndSettle();
    source.add([_n('b'), _n('a')]);
    await tester.pumpAndSettle();
    expect(find.text('قُبل حجزك b'), findsOneWidget);
  });

  testWidgets('والمقروءُ لا ينزل', (tester) async {
    await pump(tester);
    source.add([_n('a')]);
    await tester.pumpAndSettle();
    source.add([_n('b', read: true), _n('a')]);
    await tester.pumpAndSettle();
    expect(find.textContaining('قُبل حجزك'), findsNothing);
  });

  testWidgets('وضغطُه يفتح ما يشير إليه', (tester) async {
    await pump(tester);
    source.add([_n('a')]);
    await tester.pumpAndSettle();
    source.add([_n('b', data: {'booking_id': 'bk1'}), _n('a')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('قُبل حجزك b'));
    await tester.pumpAndSettle();

    expect(opened, [
      {'booking_id': 'bk1'},
    ]);
    // ويختفي بعد الضغط: بقاؤه فوق الشاشة التي فُتحت للتوّ يحجب ما ذهب إليه.
    expect(find.text('قُبل حجزك b'), findsNothing);
  });

  testWidgets('ويختفي وحده بعد خمس ثوانٍ', (tester) async {
    await pump(tester);
    source.add([_n('a')]);
    await tester.pumpAndSettle();
    source.add([_n('b'), _n('a')]);
    await tester.pumpAndSettle();
    expect(find.text('قُبل حجزك b'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('قُبل حجزك b'), findsNothing);
  });
}
