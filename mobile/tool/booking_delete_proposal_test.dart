// **صورةٌ قبل التنفيذ.** زرُّ حذف الحجز — ثلاثُ خلايا وحوارُ تأكيد.
//
//   SHOTS=<مجلّد> flutter test tool/booking_delete_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من التطبيق**: ذيلُ `BookingDetailScreen` بعينه
// كما هو اليوم — «إلغاء الحجز» و«عندي مشكلة في هذا الحجز».
//
// **والباقي مرسومٌ هنا**: الأزرارُ عناصرُ التطبيق نفسُها بثيمته
// (`OutlinedButton`, `TextButton`, `AlertDialog`) لا صناديقُ تشبهها — لكنّ
// ترتيبَها ونصوصَها مقترَحٌ لم يُكتب في `lib/` بعد.
//
// ── وما لا تُريه الصورةُ ويجب أن يُقال ──────────────────────────────────────
//
//   ١. **العميلُ اليوم لا يملك حذفَ صفٍّ من `bookings`**: السياسةُ تعطيه
//      القراءةَ وحدَها، والكتابةُ للإدارة ولدوالّ الـAPI. فأيُّ حذفٍ يحتاج
//      **دالّةً جديدةً في القاعدة تُلصق** — لا يكفي زرٌّ في الشاشة.
//   ٢. **وحذفُ الصفّ يمسّ غيرَه**: `settlement_items` تشير إليه بـ`restrict`
//      فلا يُحذف حجزٌ دخل تسويةً أصلاً، و`payments` تشير إليه بـ
//      `set null` فيبقى مبلغٌ مدفوعٌ بلا حجزٍ يُنسب إليه.
//   ٣. **والمزوّدُ طرفٌ فيه**: الحجزُ ليس ملفّاً في هاتفه بل اتّفاقٌ بين
//      اثنين، وحذفُه من القاعدة يمحوه من سجلّ المزوّد كذلك.
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
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';

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

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

/// خليّةٌ معنونة.
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.note, required this.child});
  final String label;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: child,
              ),
            ),
          ],
        ),
      );
}

/// أزرارُ الذيل كما هي اليوم — عناصرُ التطبيق بثيمته.
Widget _todayActions() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: () {}, child: const Text('إلغاء الحجز')),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.report_gmailerrorred_outlined, size: 19),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          label: const Text('عندي مشكلة في هذا الحجز'),
        ),
      ],
    );

/// (أ) إخفاءٌ من قائمته هو.
Widget _hideActions() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: () {}, child: const Text('إلغاء الحجز')),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.report_gmailerrorred_outlined, size: 19),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          label: const Text('عندي مشكلة في هذا الحجز'),
        ),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.visibility_off_outlined, size: 19),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          label: const Text('إخفاء من قائمتي'),
        ),
      ],
    );

/// (ب) حذفٌ نهائيّ.
Widget _deleteActions() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: () {}, child: const Text('إلغاء الحجز')),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.report_gmailerrorred_outlined, size: 19),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          label: const Text('عندي مشكلة في هذا الحجز'),
        ),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
          label: const Text('حذف الحجز'),
        ),
      ],
    );

/// حوارُ التأكيد — `AlertDialog` بثيمة التطبيق، ونصُّه مقترَح.
Widget _confirm(String title, String body, String action) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.7)),
      actions: [
        TextButton(onPressed: () {}, child: const Text('تراجع')),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
          child: Text(action),
        ),
      ],
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ زرّ الحذف', (tester) async {
    tester.view.physicalSize = const Size(392, 1720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

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
          key: const ValueKey('board'),
          child: Scaffold(
            backgroundColor: AppColors.page,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Cell(
                      label: 'الآن — ذيلُ صفحة الحجز',
                      note: 'إلغاءٌ وشكوى، ولا حذف',
                      child: _todayActions(),
                    ),
                    _Cell(
                      label: '(أ) «إخفاء من قائمتي»',
                      note: 'يختفي من «حجوزاتي» عندك، ويبقى عند المزوّد وفي '
                          'السجلّ. عمودٌ في القاعدة وسياسةٌ تُلصق.',
                      child: _hideActions(),
                    ),
                    _Cell(
                      label: '(ب) «حذف الحجز» — نهائيّ',
                      note: 'يُمحى الصفُّ من القاعدة فيذهب من سجلّ المزوّد '
                          'كذلك. دالّةٌ جديدةٌ تُلصق، ولا يُقبل لحجزٍ دُفع '
                          'فيه شيءٌ أو دخل تسوية.',
                      child: _deleteActions(),
                    ),
                    _Cell(
                      label: 'وحوارُ التأكيد — (أ)',
                      note: 'مرسومٌ بـ`AlertDialog` التطبيق',
                      child: _confirm(
                        'إخفاء من قائمتي',
                        'يختفي هذا الحجز من قائمتك. ويبقى عند مقدّم الخدمة '
                            'وفي سجلّ المنصّة، فلا يُعدّ إلغاءً.',
                        'إخفاء',
                      ),
                    ),
                    _Cell(
                      label: 'وحوارُ التأكيد — (ب)',
                      note: 'مرسومٌ كذلك',
                      child: _confirm(
                        'حذف الحجز',
                        'يُحذف هذا الحجز من المنصّة نهائيّاً، ويذهب من سجلّ '
                            'مقدّم الخدمة كذلك. لا رجعة فيه.',
                        'حذف',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.text('حذف الحجز'), findsWidgets);
    expect(find.text('إخفاء من قائمتي'), findsWidgets);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-delete.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });

  // **وحالُ الحجز تُرى في الشاشة الحقيقيّة**: أيُّ الأزرار يظهر اليوم
  // لحجزٍ أُلغي — فموضعُ زرّ الحذف بينها لا في فراغ.
  testWidgets('لقطةُ ذيل الشاشة الحقيقيّة لحجزٍ ملغى', (tester) async {
    tester.view.physicalSize = const Size(392, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final rejected =
        demoBookings.firstWhere((b) => b.status == BookingStatus.rejected);

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
          key: const ValueKey('real'),
          child: BookingDetailScreen(
            booking: rejected,
            session: _session(),
            reviewed: false,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // يُنزل إلى الذيل حيث الأفعال.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('real')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-detail-tail.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
