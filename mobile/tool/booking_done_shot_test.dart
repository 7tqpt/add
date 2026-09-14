// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `RequestsScreen` بعينها من
// الشيفرة المدفوعة، وفيها رحلةُ «تأكيد التنفيذ» كلُّها في لقطةٍ واحدة.
//
//   SHOTS=<مجلّد> flutter test tool/booking_done_shot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/requests.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // **وحدُّ الرسم خارجَ `home`.** الطرقُ المدفوعةُ تعيش في ملّاح
      // `MaterialApp` لا في `home`، وطريقٌ معتمٌ يُخرج ما تحته من الشجرة
      // المرئيّة — فلا يجد المصوِّرُ حدَّه ويسقط بـ«No element». وقد وقع.
      builder: (_, navigator) => RepaintBoundary(
        key: const ValueKey('shot'),
        child: navigator!,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

Booking _booking({
  required String id,
  required String user,
  required int inDays,
  required BookingStatus status,
  required num price,
  String requestedAt = '',
  String rejectReason = '',
}) => Booking(
      id: id,
      reference: 'BK-2026-000$id',
      userName: user,
      providerName: 'قاعة التاج',
      serviceTitle: 'خيمة الأفراح',
      eventDate: DateTime.now()
          .add(Duration(days: inDays))
          .toIso8601String()
          .substring(0, 10),
      eventTime: '20:00',
      address: 'شارع الستين — صنعاء',
      guestsCount: 350,
      status: status,
      totalPrice: price,
      depositAmount: price * 0.3,
      paidAmount: price,
      completionRequestedAt: requestedAt,
      completionRejectReason: rejectReason,
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // **وأربعةٌ لا واحد:** الرحلةُ كلُّها في لقطةٍ واحدة — منفَّذٌ مختوم،
    // وواحدٌ ينتظر الإدارة، وواحدٌ رُدَّ طلبُه بسبب، وواحدٌ لم يُطلب بعد.
    demoProviderRequests = [
      _booking(
        id: '1',
        user: 'هدى المقطري',
        inDays: -12,
        status: BookingStatus.completed,
        price: 480000,
      ),
      _booking(
        id: '2',
        user: 'سالم باحميد',
        inDays: -4,
        status: BookingStatus.confirmed,
        price: 700000,
        requestedAt: '2026-09-10T12:00:00Z',
      ),
      _booking(
        id: '3',
        user: 'نورة الحضرمي',
        inDays: -6,
        status: BookingStatus.confirmed,
        price: 300000,
        rejectReason: 'العربون لم يصل بعد — راجع إبلاغك بالحوالة.',
      ),
      _booking(
        id: '4',
        user: 'خالد التعزّي',
        inDays: -2,
        status: BookingStatus.confirmed,
        price: 520000,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الطلبات — الحالاتُ الأربع', (tester) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الفرقَ رُسم: تُسأل الشجرة.**
    expect(find.byKey(const ValueKey('booking-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-under-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-rejected')), findsOneWidget);
    expect(find.byKey(const ValueKey('request-completion-4')), findsOneWidget);
    expect(find.text('راسل هدى المقطري'), findsNothing);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/booking-done.png');
  });

  // **وبابُ الشريط يُصوَّر بعد فتحه.** سؤالُ «هل فُتحت الشاشة؟» يمرّ على
  // شاشةٍ بلا عنوانٍ ولا سهمِ رجوع — وقد وقع ذلك فعلاً.
  testWidgets('وما يُفتح بضغط الشريط', (tester) async {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('booking-done')));
    await _settle(tester);

    expect(find.widgetWithText(AppBar, 'مستحقّاتي'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await _shoot(tester, '$out/booking-done-earnings.png');
  });
}
