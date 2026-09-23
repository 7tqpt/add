// **مقترحٌ لا تنفيذ.** سؤالُ الإشعارات عند فتح «الرسائل».
//
//   SHOTS=<مجلّد> flutter test tool/notify_ask_proposal_test.dart
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريدها تكون عند ضغط على الرسائل، وتكون نصّ: هل تريد السماح للإشعارات
// بالوصول — سماح ورفض».
//
// ── ولماذا هذا أحسنُ من الأوّل ────────────────────────────────────────────
//
// كان حوارُ أندرويد يُفتح **بعد الدخول مباشرةً**، ونصُّه من عنده: «هل تريد
// إيقاف تحسين استخدام البطّاريّة؟ سيكون بمقدور فرحتي التشغيل في الخلفية».
// فيقع في أوّل لحظةٍ وبكلامٍ لا يخصّ ما جاء له العميل — فيُقرأ عطباً.
//
// وهذا يقع **حيث للسؤال معنى**: من فتح «الرسائل» ينتظر ردّاً، فسؤالُه عن
// وصول الإشعارات في تلك اللحظة يُقرأ سبباً. ونصُّه نصُّنا لا نصُّ النظام.
//
// ── وما يقع خلفه ──────────────────────────────────────────────────────────
//
// «رفض» → لا شيء، ولا يُسأل ثانيةً.
// «سماح» → يُفتح حوارُ النظام (هو نفسُه) — لكنّ صاحبَه الآن **طلبه**، فلا
// يُفاجأ به ولا يظنّه عطباً.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ**: `ConversationsScreen` المدفوعةُ بعينها، بلا
// حوارٍ فوقها — وهي ما يراه العميل الآن.
//
// **وخليّةُ «المقترح» مرسومةٌ ويُقال** — غيرُ منفَّذةٍ بعد. والحوارُ فيها
// `AlertDialog` بثيمة التطبيق (`buildTheme()`) فوق الشاشة المصوَّرة نفسِها،
// لا صندوقٌ مرسومٌ بالألوان.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';

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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 360.0;
const _ph = 640.0;
const _scale = 0.72;

Widget _panel({
  required String caption,
  required String note,
  required Color captionColour,
  required Widget screen,
}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _pw * _scale,
          height: _ph * _scale,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: _pw, height: _ph, child: screen),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: _pw * _scale,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w700, color: captionColour)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _pw * _scale,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(fontSize: 11.5, color: AppColors.muted, height: 1.45)),
        ),
      ],
    );

/// حوارُنا نحن — بثيمة التطبيق، ونصُّه نصُّ صاحب المنصّة.
Widget _ourDialog(Widget behind) => Stack(
      fit: StackFit.expand,
      children: [
        behind,
        Container(color: Colors.black.withValues(alpha: 0.42)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('هل تريد السماح للإشعارات بالوصول؟',
                        style: _label.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 10),
                    Text(
                      'لتصلك ردودُ مقدّم الخدمة وتأكيدُ حجزك في وقتها، حتى '
                      'والتطبيق مغلق.',
                      style: _label.copyWith(
                          fontSize: 13.5, color: AppColors.ink2, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('رفض',
                            style: _label.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                        const SizedBox(width: 24),
                        Text('سماح',
                            style: _label.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

Widget _board(Widget chats, Widget chatsWithDialog) => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سؤالُ الإشعارات عند فتح «الرسائل»',
              style: _label.copyWith(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 3),
          Text(
            'الشاشةُ في الخليّتين مصوَّرةٌ من الشيفرة المدفوعة. والحوارُ في اليسرى '
            'مرسومٌ — غيرُ منفَّذٍ بعد — بحوار ماتيريال نفسِه وثيمة التطبيق.',
            style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم — عند فتح الرسائل',
                note: 'لا يُسأل شيء. والحوارُ الذي شكوتَ منه\nكان يقع في أوّل فتحةٍ للتطبيق.',
                captionColour: AppColors.ink,
                screen: chats,
              ),
              const SizedBox(width: 26),
              _panel(
                caption: 'المقترح — نصُّك أنت',
                note: '«رفض» لا شيءَ ولا يُسأل ثانيةً.\n«سماح» يفتح إذنَ النظام وقد طلبه بنفسه.',
                captionColour: AppColors.accent,
                screen: chatsWithDialog,
              ),
            ],
          ),
        ],
      ),
    );

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
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
          child: Scaffold(backgroundColor: AppColors.surface, body: child),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ سؤال الإشعارات', (tester) async {
    tester.view.physicalSize = const Size(760, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const chats = SizedBox(width: _pw, height: _ph, child: ConversationsScreen());

    await tester.pumpWidget(_wrap(_board(chats, _ourDialog(chats))));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(ConversationsScreen), findsNWidgets(2),
        reason: 'الشاشةُ المصوَّرةُ غائبةٌ من إحدى الخليّتين');
    expect(find.text('هل تريد السماح للإشعارات بالوصول؟'), findsOneWidget);
    expect(find.text('سماح'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/notify-ask.png');
  });
}
