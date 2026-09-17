// **مقترحٌ لا تنفيذ.** صورةُ الطرف الآخر في قائمة «المحادثات».
//
//   SHOTS=<مجلّد> flutter test tool/conversations_avatar_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما قاله ────────────────────────────────────────────────────────────────
//
// أرسل لقطةَ قائمة «المحادثات» وقال: «صورة لم تظهر هنا». **والقائمةُ غيرُ
// الشريط**: المدموجُ في ١٫٥٢ هو رأسُ شاشة المحادثة نفسِها، أمّا هذه القائمةُ
// فما زالت `CircleAvatar` بحرف الاسم كما كانت.
//
// **والبياناتُ تصلها فعلاً:** كلُّ صفٍّ في يده `conversation.otherAvatar` منذ
// أن أُضيف العمودُ إلى `v_my_conversations`. فلا ينقص إلّا الرسم.
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **الصفُّ مرسوم**: `_Row` خاصٌّ بـ`conversations.dart` ولا مدخلَ لصورته،
// فلا يُصوَّر ما لم يُكتب. والمرسومُ نسخةٌ حرفيّةٌ من بنائه: `ListTile`
// و`CircleAvatar` بنصف قطر ٢٢ وأرضيّةِ `accent` بشفافيّة ١٠٪، والاسمُ ١٥
// والسطرُ الخافتُ تحته، والزمنُ في الطرف.
//
// **والصورةُ نفسُها مرسومةٌ ويُقال**: لا شبكةَ في `flutter test` فلا تُجلب
// صورةُ أحد، ولا سلّةَ `avatars` تُفتح. فرُسم مكانَها **تدرّجٌ** يقوم مقامَ
// صورةٍ حقيقيّةٍ ليُرى الشكلُ لا الصورة. وفي الجهاز تكون صورةَ القاعة.
//
// **والحروفُ تبقى للأكثرين:** أكثرُ الحسابات بلا صورة، ومقدّمُ الخدمة لا
// تصله صورةُ العميل أصلاً (سياسةُ `app_users`). فاللقطةُ تُري الحالين معاً
// في قائمةٍ واحدة — لا صفوفاً كلُّها صور.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';

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

/// صفٌّ في القائمة — **ولا رقمَ إنسانٍ ولا اسمَ حسابٍ حقيقيٍّ في الشجرة**.
typedef _Thread = ({String name, String last, String when, bool photo, int unread});

const _threads = <_Thread>[
  (name: 'قاعة اللؤلؤة للأفراح', last: 'أنت: تمام، نتفق على الخميس', when: 'منذ ساعة', photo: true, unread: 0),
  (name: 'مطبخ الأصايل', last: 'الأسعار تشمل الخدمة والتوصيل', when: 'منذ ٤ أيام', photo: true, unread: 2),
  (name: 'استوديو الضوء', last: '🎤 رسالة صوتية', when: 'منذ ٥ أيام', photo: false, unread: 0),
  (name: 'صالة النخبة', last: 'أنت: في الصفحة الحساب في زر أريد أقدم خدمة', when: 'منذ ٢٣ يوماً', photo: false, unread: 0),
];

/// القرصُ — صورةٌ **مرسومة** أو حرفُ الاسم.
Widget _disc({required String name, required bool photo}) => CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.accent.withValues(alpha: 0.10),
      child: photo
          ? Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.accentLift, AppColors.accentDeep],
                ),
              ),
            )
          : Text(
              name.characters.first,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                fontFamilyFallback: arabicFallback,
              ),
            ),
    );

/// نسخةٌ حرفيّةٌ من `_Row` — والقرصُ وحدَه ما يفترق بين المقترحين.
Widget _row(_Thread t, {required bool withPhotos}) => ListTile(
      onTap: () {},
      leading: _disc(name: t.name, photo: withPhotos && t.photo),
      title: Row(
        children: [
          Expanded(
            child: Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: t.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(t.when, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
      subtitle: Text(
        t.last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: t.unread > 0 ? AppColors.ink2 : AppColors.muted,
          fontWeight: t.unread > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );

Widget _wrap({required bool withPhotos}) => MaterialApp(
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
            appBar: AppBar(title: Text(tr('المحادثات'))),
            body: ListView(
              children: [
                for (final t in _threads) ...[
                  _row(t, withPhotos: withPhotos),
                  const Divider(height: 1, color: AppColors.hairline),
                ],
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  for (final (name, photos) in const [('today', false), ('a', true)]) {
    testWidgets('قائمةُ المحادثات — $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 1100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(withPhotos: photos));
      await tester.pumpAndSettle();

      expect(find.text('قاعة اللؤلؤة للأفراح'), findsOneWidget,
          reason: 'لم تُبنَ القائمة — فلا شيءَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/convos-$name.png');
    });
  }
}
