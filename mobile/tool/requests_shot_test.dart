// **تصويرُ شاشة «الطلبات»** عند مقدّم الخدمة — قبل التعديل وبعده.
//
//   SHOTS=<مجلّد> flutter test tool/requests_shot_test.dart
//
// **ولا شيءَ هنا مرسوم**: `RequestsScreen` بعينها ببيانات وضع العرض.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/requests.dart';
import 'package:aras/src/screens/availability.dart';
import 'package:aras/src/screens/plan.dart';
import 'package:aras/src/screens/services.dart';

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
  await initializeDateFormatting('ar');
}

// ── شبكةٌ مركَّبة تردّ صورةً واحدة ───────────────────────────────────────────
class _OneImageHttp extends HttpOverrides {
  _OneImageHttp(this.bytes);
  final Uint8List bytes;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(bytes);
}

class _Client implements HttpClient {
  _Client(this.bytes);
  final Uint8List bytes;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;

  @override
  final HttpHeaders headers = _Headers();

  @override
  Future<HttpClientResponse> close() async => _Response(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Session _customer() => Session()
  ..userId = 'u2'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطةُ شاشة الطلبات', (tester) async {
    tester.view.physicalSize = const Size(392, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    // **وطلباتُ العرض لا تُزرع إلّا لمزوّدٍ موثَّق** — وبلا هذا تخرج
    // الشاشةُ فارغةً وتُقرأ «لا طلبات» على أنّها الشاشة.
    demoBecomeProvider(
      businessName: 'قاعة التاج',
      governorate: 'أمانة العاصمة',
      bio: 'قاعةُ أفراحٍ في صنعاء',
    );
    demoApproveProvider();

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('one'),
          child: Scaffold(
            appBar: AppBar(title: const Text('الطلبات')),
            body: RequestsScreen(session: _provider()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/requests.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });

  testWidgets('ولقطةُ «خطة العرس»', (tester) async {
    tester.view.physicalSize = const Size(392, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    // **وغلافُ الصدر يحتاج شبكةً مركَّبة**: بدونها لا تُبنى `Image` أصلاً
    // فتخرج اللقطةُ بلا صورة — وهي حالُ من لم يحجز، لا حالُ من حجز.
    final cover = Platform.environment['COVER'];
    if (cover != null && File(cover).existsSync()) {
      HttpOverrides.global = _OneImageHttp(File(cover).readAsBytesSync());
      Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    }
    addTearDown(() {
      HttpOverrides.global = null;
      Api.mediaUrlOverride = null;
    });

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('plan'),
          child: Scaffold(
            appBar: AppBar(title: const Text('خطة العرس')),
            body: PlanScreen(session: _customer()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // **والصورةُ تُفكّ على خيطٍ آخر فتحتاج زمناً حقيقيّاً.**
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('plan')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/plan.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });

  // **وحالُ الختام**: مهامُّ الخطّة كلُّها منجَزة — وهي الحالُ التي في
  // تصميم صاحب المنصّة.
  testWidgets('ولقطةُ الخطّة وقد تمّ كلُّ شيء', (tester) async {
    tester.view.physicalSize = const Size(392, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    demoPlanTasks = [
      for (final t in demoPlanTasks)
        PlanTask(
          id: t.id,
          title: t.title,
          done: true,
          dueDate: t.dueDate,
          sortOrder: t.sortOrder,
        ),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('plan-done'),
          child: Scaffold(
            appBar: AppBar(title: const Text('خطة العرس')),
            body: PlanScreen(session: _customer()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('plan-done')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/plan-done.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });

  testWidgets('ولقطةُ «تقويمي»', (tester) async {
    tester.view.physicalSize = const Size(392, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    demoBecomeProvider(
      businessName: 'قاعة التاج',
      governorate: 'أمانة العاصمة',
      bio: 'قاعةُ أفراحٍ في صنعاء',
    );
    demoApproveProvider();
    // يومان مغلقان: واحدٌ بحجزٍ وآخرُ أغلقه صاحبُه — ليُرى الصفّان.
    final now = DateTime.now();
    demoDays = [
      DayMark(
        day: DateTime(now.year, now.month, 10),
        blocked: true,
        note: 'غير متاح',
      ),
      DayMark(
        day: DateTime(now.year, now.month, 20),
        blocked: true,
        // و`byBooking` تُقرأ من النصّ نفسِه: «محجوز» في أوّله.
        note: 'محجوز — BK-2026-FB8D3DF2',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('cal'),
          child: Scaffold(
            appBar: AppBar(title: const Text('تقويمي')),
            body: AvailabilityScreen(session: _provider()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('cal')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/calendar.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });

  testWidgets('ولقطةُ «خدماتي»', (tester) async {
    tester.view.physicalSize = const Size(392, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    demoBecomeProvider(
      businessName: 'قاعة التاج',
      governorate: 'أمانة العاصمة',
      bio: 'قاعةُ أفراحٍ في صنعاء',
    );
    demoApproveProvider();
    // وخدمتان: معروضةٌ وموقوفة، ليُرى لونا الشارتين.
    demoMyServices = [
      const MyService(
        id: 's1',
        title: 'قاعة التاج',
        description: 'قاعة التاج التاريخية',
        price: 10000,
        priceTo: 100000,
        unit: 'لليوم',
        depositPercent: 30,
        categoryId: 'c1',
        isActive: true,
      ),
      const MyService(
        id: 's2',
        title: 'خيمة أفراح متنقّلة',
        description: '',
        price: 150000,
        priceTo: null,
        unit: 'للحجز',
        depositPercent: 25,
        categoryId: 'c1',
        isActive: false,
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('two'),
          child: Scaffold(
            appBar: AppBar(title: const Text('خدماتي')),
            body: ServicesScreen(session: _provider()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('two')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/services.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
