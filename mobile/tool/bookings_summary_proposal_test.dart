// **صورةٌ قبل التنفيذ.** بطاقةُ ملخّص «حجوزاتي» — ثلاثُ خلايا.
//
//   SHOTS=<مجلّد> flutter test tool/bookings_summary_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ اليمنى مصوَّرةٌ من التطبيق**: `MyBookingsScreen` بعينها ببيانات
// وضع العرض، مقصوصةً على بطاقة الملخّص.
//
// **والوسطى واليسرى مرسومتان** بعناصر التطبيق وثيمته — وليستا في الشجرة.
//
// ── وثلاثةُ مآخذَ على القائمة اليوم ────────────────────────────────────────
//
//   ١. **اللونُ طَفليٌّ محروقٌ لا نبيذيّ** — اختير ليطابق بلاطةَ «حجوزاتي»
//      في الرئيسية. وهو في الرئيسية بلاطةٌ صغيرةٌ بين أخواتٍ ملوّنة، وهنا
//      بطاقةٌ تملأ عرضَ الشاشة فوق بطاقاتٍ بيضاءَ نبيذيّةِ التفاصيل — فيقع
//      لونان لا يجتمعان.
//   ٢. **وسهمٌ لا يفتح شيئاً**: `BigHeroCard` ترسم السهمَ دائماً، و`onTap`
//      هنا `null` عمداً — فالبطاقةُ في الشاشة التي تشير إليها. فيُرى سهمٌ
//      يُضغط فلا يقع شيء.
//   ٣. **وأربعةُ أسطرٍ نصّيّةٍ مرصوصة**: «حجوزاتي» و«8 حجوزات» و«أقربها…»
//      و«مؤكّد 1 · بانتظار المزوّد 1» — والأخيرُ سطرٌ يُقرأ حرفاً حرفاً،
//      وهو عددان.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';

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

const _cw = 340.0;
const _ch = 320.0;

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

/// عددٌ فوق كلمته — يُقرأ بلمحةٍ لا حرفاً حرفاً.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.tinted});
  final String value;
  final String label;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tinted ? Colors.white : AppColors.accent,
              )),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: tinted
                    ? Colors.white.withValues(alpha: 0.80)
                    : AppColors.muted,
              )),
        ],
      );
}

/// ملخّصٌ مقترَح.
///
/// `tinted` يجعله نبيذيّاً بتدرّج التطبيق؛ وإلّا فأبيضُ كالبطاقات تحته.
class _Proposed extends StatelessWidget {
  const _Proposed({required this.summary, required this.tinted});
  final BookingsSummary summary;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final ink = tinted ? Colors.white : AppColors.ink;
    final soft =
        tinted ? Colors.white.withValues(alpha: 0.82) : AppColors.muted;
    final next = summary.next;

    return Container(
      decoration: BoxDecoration(
        gradient: tinted
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.accentLift, AppColors.accentDeep],
              )
            : null,
        color: tinted ? null : AppColors.surface,
        border: tinted ? null : Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tinted
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.surface2,
                ),
                child: Icon(Icons.event_available_rounded,
                    size: 17, color: tinted ? Colors.white : AppColors.accent),
              ),
              const SizedBox(width: 10),
              // **والرقمُ في الصدارة، والكلمةُ تابعةٌ له.**
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${summary.count}',
                        style: TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: ink)),
                    TextSpan(
                        text: ' حجوزات قادمة',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: soft)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // **ولا سهمَ**: البطاقةُ في الشاشة التي تشير إليها.
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tinted
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: soft),
                    const SizedBox(width: 5),
                    Text(
                      'أقربها ${formatDate(next.eventDate)} · ${next.providerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: soft),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(
              height: 1,
              color: tinted
                  ? Colors.white.withValues(alpha: 0.22)
                  : AppColors.hairline),
          const SizedBox(height: 10),
          // **عددان فوق كلمتيهما** بدل سطرٍ يُقرأ حرفاً حرفاً.
          Row(
            children: [
              Expanded(
                child: _Stat(
                    value: '${summary.confirmed}',
                    label: 'مؤكّد',
                    tinted: tinted),
              ),
              Container(
                width: 1,
                height: 28,
                color: tinted
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.hairline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                    value: '${summary.pending}',
                    label: 'بانتظار المزوّد',
                    tinted: tinted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _cell(String title, String note, Widget child, {Color? tone}) => Container(
      width: _cw,
      height: _ch,
      color: AppColors.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tone ?? AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(note,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ مقترح ملخّص حجوزاتي', (tester) async {
    tester.view.physicalSize = const Size(1040, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final summary = BookingsSummary.of(demoBookings);

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
      // **والسقّالةُ ليست زينة**: بلا `Scaffold` لا يسري `fontFamily` من
      // الثيمة على النصّ المرسوم، فتخرج الأرقامُ مربّعاتٍ سوداء.
      home: Scaffold(
        backgroundColor: AppColors.page,
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const ValueKey('board'),
            child: Row(
              children: [
                _cell(
                  'اليومَ — مصوَّرةٌ من التطبيق',
                  'طَفليٌّ محروقٌ، وسهمٌ لا يفتح شيئاً، وأربعةُ أسطرٍ مرصوصة.',
                  ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: 1400,
                      child: SizedBox(
                        width: _cw,
                        height: 1400,
                        child: MyBookingsScreen(session: _session()),
                      ),
                    ),
                  ),
                ),
                _cell(
                  '(أ) نبيذيّةٌ كهويّة التطبيق — مرسومة',
                  'التدرّجُ نفسُه الذي في رأس «تفاصيل الحجز» و«خطة العرس»، '
                      'والعددُ في الصدارة، وعددان فوق كلمتيهما — ولا سهم.',
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Proposed(summary: summary, tinted: true),
                  ),
                  tone: AppColors.accent,
                ),
                _cell(
                  '(ب) بيضاءُ كبطاقات الحجز تحتها — مرسومة',
                  'الترتيبُ نفسُه بحبرٍ داكنٍ وأرقامٍ نبيذيّة، فتتّسق مع '
                      'البطاقات التي تليها ولا تنافسها.',
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Proposed(summary: summary, tinted: false),
                  ),
                  tone: AppColors.accentDeep,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.text('حجوزاتي'), findsWidgets,
        reason: 'الشاشةُ الحقيقيّةُ لم تُبنَ — فاللوحُ يقابل فراغاً');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/bookings-summary-proposal.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
