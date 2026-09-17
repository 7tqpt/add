// **مقترحٌ لا تنفيذ.** بطاقةُ العميل كما يراها مقدّمُ الخدمة من شريط
// المحادثة.
//
//   SHOTS=<مجلّد> flutter test tool/customer_card_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما اختاره ──────────────────────────────────────────────────────────────
//
// ضغط صاحبُ المنصّة شريطَ المحادثة بحساب مقدّم خدمةٍ فلم يُفتح شيء — وهو ما
// اختاره قبلُ، إذ لا صفحةَ ملفٍّ للعميل في التطبيق. ثمّ اختار أن تُبنى:
// «**(ب) مثلُها ومعها صورتُه ومحافظتُه عبر دالّةٍ ضيّقةٍ تُرجع هذين وحدَهما
// لطرفَي محادثةٍ قائمة**».
//
// ── وحدُّ ما فيها ليس ذوقاً بل ما تسمح به القاعدة ──────────────────────────
//
// **ممّا يملكه مقدّمُ الخدمة اليومَ بلا مسّ أيّ سياسة:** اسمُ العميل (مخزونٌ
// في `conversations` و`bookings`)، وحضورُه (`api_conversation_presence`)،
// **وسجلُّه معه هو** — محسوبٌ من حجوزات مقدّم الخدمة نفسِه التي يقرؤها
// اليوم، لا من صفّ العميل.
//
// **وما لا يملكه:** صورتُه ومحافظتُه. سياسةُ `app_users` صريحة: «العميل يرى
// ويعدّل حسابه هو. لا يرى حسابات غيره إطلاقاً» — وهي تشمله. فتُجلبان بدالّةٍ
// `security definer` تُرجع **هذين الحقلين وحدَهما** لمن بينه وبين العميل
// محادثةٌ قائمة، ولا تفتح البريدَ ولا الجوالَ ولا حالةَ الحساب.
//
// **ولا جوّالَ في البطاقة.** لم يطلبه، وليس في الحجوزات أصلاً — ورقمُ إنسانٍ
// لا يُعرض لأنّه «قد ينفع».
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **البطاقاتُ والسطورُ حقيقيّة:** `AppCard` و`SectionTitle` و`KeyValue`
// و`Muted` و`StatusBadge` و`PresenceLine` — كلُّها المشحونةُ بثيمة التطبيق،
// والأرقامُ تمرّ بـ`formatMoney` و`formatCount` المشحونتين.
//
// **والقرصُ مرسوم**: لا شبكةَ في `flutter test` تجلب صورةَ أحد، فرُسم
// تدرّجٌ مكانَها ليُرى الشكلُ لا الصورة.
//
// **والأسماءُ والأرقامُ من نسجٍ لا من أحد**: لا اسمَ عميلٍ حقيقيّ ولا رقمَ
// إنسانٍ في الشجرة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

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
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _name = 'أحمد الشرعبي';
const _governorate = 'صنعاء';

/// القرصُ — **مرسومٌ** مكانَ الصورة.
Widget _disc(double size) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.accentLift, AppColors.accentDeep],
        ),
      ),
    );

/// سجلُّه معك — **من حجوزاتك أنت**، لا من صفّه.
List<Widget> _history() => [
      SectionTitle(tr('حجوزاته معك')),
      const SizedBox(height: Space.sm),
      Muted(trf('أوّلُ حجزٍ في {0}', ['مارس ٢٠٢٥']), size: 12),
      const SizedBox(height: Space.md),
      const Divider(height: 1, color: AppColors.hairline),
      KeyValue(tr('الحجوزات'), formatCount(7, bookingForms)),
      const Divider(height: 1, color: AppColors.hairline),
      KeyValue(tr('المكتملة'), '٥'),
      const Divider(height: 1, color: AppColors.hairline),
      KeyValue(tr('الملغاة'), '١'),
      const Divider(height: 1, color: AppColors.hairline),
      KeyValue(tr('القادمة'), '١'),
      const Divider(height: 1, color: AppColors.hairline),
      KeyValue(tr('إجمالي ما دفعه لك'), formatMoney(1250000)),
    ];

/// (أ) رأسٌ عريضٌ فوق، والسجلُّ في بطاقةٍ تحته.
Widget _wide() => ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Column(
          children: [
            _disc(96),
            const SizedBox(height: Space.md),
            Text(
              _name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            PresenceLine(lastSeen: DateTime.now(), center: true),
            const SizedBox(height: Space.sm),
            StatusBadge(_governorate, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: Space.xl),
        AppCard(children: _history()),
      ],
    );

/// (ب) بطاقةٌ واحدة: قرصٌ في صفٍّ مع الاسم، والسجلُّ تحته.
Widget _compact() => ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppCard(
          children: [
            Row(
              children: [
                _disc(56),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      PresenceLine(lastSeen: DateTime.now(), size: 12),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Muted(_governorate, size: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: Space.md),
            ..._history(),
          ],
        ),
      ],
    );

Widget _wrap(Widget body) => MaterialApp(
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
          key: const ValueKey('shot'),
          child: Scaffold(
            appBar: AppBar(leading: const BackButton(), title: Text(tr('العميل'))),
            body: body,
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  for (final (file, body) in [('a', _wide()), ('b', _compact())]) {
    testWidgets('بطاقةُ العميل — $file', (tester) async {
      tester.view.physicalSize = const Size(1080, 1900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(body));
      await tester.pumpAndSettle();

      expect(find.text(_name), findsOneWidget,
          reason: 'لم تُبنَ البطاقة — فلا شيءَ في اللقطة');
      expect(find.text('حجوزاته معك'), findsOneWidget);
      // **ولا جوّالَ ولا بريدَ في الشجرة** — وهما ما لا تُعطيه القاعدة.
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('+967'), findsNothing);
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/customer-card-$file.png');
    });
  }
}
