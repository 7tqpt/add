// **بطاقةُ الخدمة** بتصميم صاحب المنصّة: غلافٌ بعرض البطاقة يعلوه القلب،
// ثمّ الاسمُ والمزوّدُ والمكان، ثمّ السعرُ والتقييم، ثمّ خطٌّ وزرٌّ بعرضها.
//
// **وواحدةٌ في ثلاثة مواضع**: «استكشف» و«المفضّلة» وقائمةُ خدمات المزوّد.
// فما يُقاس هنا يعمّ الثلاثة، وما يسقط هنا يسقط فيها.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/service_card.dart';

Widget _wrap(Widget child) => MaterialApp(
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
    // حدُّ رسمٍ حول الشاشة — تُصوَّر منه البكسلات حين لا يكفي سؤالُ الشجرة.
    child: RepaintBoundary(
      key: const ValueKey('card-paint'),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  ),
);

ServiceItem get _withCover => demoServices.firstWhere((s) => s.coverPath != null);
ServiceItem get _noCover => demoServices.firstWhere((s) => s.coverPath == null);

void main() {
  testWidgets('**الغلافُ يبلغ حافّتَي البطاقة لا مربّعاً إلى جانب الاسم**',
      (tester) async {
    // **ويُقاس بالعرض لا بوجود الصورة**: الغلافُ كان مربّعاً ‎٧٦×٧٦‎ إلى جانب
    // العنوان، وتصميمُ صاحب المنصّة يجعله لوحاً بعرض البطاقة يعلوه القلب.
    final s = _withCover;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(Card));
    final cover = tester.getRect(find.byKey(ValueKey('cover-${s.id}')));

    expect(cover.width, closeTo(card.width, 1),
        reason: 'الغلافُ لا يبلغ حافّتَي البطاقة');
    expect(cover.height, ServiceListCard.coverHeight,
        reason: 'ارتفاعُ الغلاف ليس الارتفاعَ المعلن');
  });

  testWidgets('**ومن لا غلافَ له يرى تدرّجاً وحرفاً لا مربّعاً رمادياً**',
      (tester) async {
    // **ولا يكفي سؤالُ الشجرة**: لوحُ `surface2` الباهت عنصرٌ قائمٌ كالتدرّج،
    // وكلاهما يُرضي «هل هناك غلاف؟». فتُقرأ البكسلات: أهي داكنةُ العلامة أم
    // رماديّةُ «صورةٌ لم تُحمَّل»؟
    final s = _noCover;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    // الحرفُ الأوّلُ من اسم الخدمة — لا أيقونةُ صورةٍ مكسورة.
    expect(find.text(s.title.trim().characters.first), findsOneWidget,
        reason: 'لا حرفَ على أرضيّة الغلاف');
    expect(find.byIcon(Icons.image_outlined), findsNothing,
        reason: 'أيقونةُ «صورةٌ لم تُحمَّل» على خدمةٍ لم يُرفع لها غلافٌ أصلاً');

    final cover = tester.getRect(find.byKey(ValueKey('cover-${s.id}')));
    late ByteData pixels;
    late int width;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('card-paint')));
      final image = await boundary.toImage();
      width = image.width;
      pixels = (await image.toByteData())!;
      image.dispose();
    });

    // **ونقطةُ القياس تُحسب من مستطيل الغلاف لا تُكتب رقماً**: رقمٌ مكتوبٌ
    // يقع على أرضيّة الصفحة فيُقرأ بياضُها عطباً — وقد وقع من قبل.
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final scale = width / logicalWidth;
    final x = ((cover.left + 12) * scale).round();
    final y = ((cover.top + 12) * scale).round();
    int at(int c) => pixels.getUint8(((y * width) + x) * 4 + c);
    final luma = (0.2126 * at(0) + 0.7152 * at(1) + 0.0722 * at(2)) / 255;
    expect(luma, lessThan(0.4),
        reason: 'زاويةُ الغلاف فاتحةٌ — لوحٌ باهتٌ لا تدرّجُ العلامة '
            '(لمعان ${luma.toStringAsFixed(2)})');
  });

  testWidgets('**وزرُّ «عرض التفاصيل» هو البابُ — ويُقاس من زرّ بطاقته**',
      (tester) async {
    // **ومن مفتاح البطاقة لا من نصِّ الزرّ**: قائمةُ الاستكشاف عشرون بطاقةً
    // في كلٍّ منها زرٌّ بالنصّ نفسِه، فسؤالٌ بالنصّ يلتقط أوّلَها.
    final s = _withCover;
    var opened = 0;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () => opened++)));
    await tester.pumpAndSettle();

    final button = find.byKey(ValueKey('open-${s.id}'));
    expect(button, findsOneWidget, reason: 'لا زرَّ تفاصيلَ على البطاقة');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull,
        reason: 'الزرُّ معطَّل');

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, 1, reason: 'الضغطةُ على الزرّ لم تفتح الخدمة');
  });

  testWidgets('**والقلبُ على الغلاف يحفظ ولا يفتح الخدمة**', (tester) async {
    // **وهذا يسقط بسهولة**: القلبُ فوق غلافٍ تحته بطاقةٌ كلُّها تُضغط —
    // فإن لم يكن له سطحُه الخاصّ ذهبت الضغطةُ إلى البطاقة وفُتحت الخدمة.
    final s = _withCover;
    var opened = 0;
    var toggled = 0;
    await tester.pumpWidget(_wrap(ServiceListCard(
      item: s,
      onOpen: () => opened++,
      isFavourite: false,
      onToggleFavourite: () => toggled++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(toggled, 1, reason: 'الضغطةُ على القلب لم تحفظ');
    expect(opened, 0, reason: 'الضغطةُ على القلب فتحت الخدمة');
  });

  testWidgets('**والقلبُ يغيب حيث لا مفضّلة**', (tester) async {
    // قائمةُ خدمات المزوّد لا قلبَ فيها — وقلبٌ لا يحفظ شيئاً كذبٌ مرسوم.
    await tester.pumpWidget(_wrap(ServiceListCard(item: _withCover, onOpen: () {})));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('**ولا قسمَ ولا وحدةَ على البطاقة**', (tester) async {
    // أسقطهما صاحبُ المنصّة من تصميمه: القسمُ يُعرف من الترشيح الذي جاء
    // منه، والوحدةُ تُقرأ في صفحة الخدمة.
    final s = _withCover;
    await tester.pumpWidget(_wrap(ServiceListCard(
      item: s,
      onOpen: () {},
      onOpenProvider: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining(s.categoryName), findsNothing,
        reason: 'القسمُ ما زال على البطاقة');
    expect(find.textContaining(s.unit), findsNothing,
        reason: 'الوحدةُ ما زالت على البطاقة');
    // والعربونُ يبقى وحدَه.
    expect(find.textContaining('العربون'), findsOneWidget);
  });

  testWidgets('**وشارتا «فيديو» و«مقطع صوتي» تبقيان**', (tester) async {
    // **وهما الخبرُ الوحيدُ أنّ وراء البطاقة ما يُرى ويُسمع**: من لم يفتح
    // الخدمةَ لم يعرف. اختارها صاحبُ المنصّة صراحةً حين أسقط ما عداها.
    final s = demoServices.firstWhere((s) => s.hasVideo);
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();
    expect(find.text('فيديو'), findsOneWidget);

    final a = demoServices.firstWhere((s) => s.hasAudio);
    await tester.pumpWidget(_wrap(ServiceListCard(item: a, onOpen: () {})));
    await tester.pumpAndSettle();
    expect(find.text('مقطع صوتي'), findsOneWidget);
  });

  testWidgets('**واسمُ المزوّد بابٌ إلى ملفّه لا يفتح الخدمة**', (tester) async {
    final s = _withCover;
    var opened = 0;
    var provider = 0;
    await tester.pumpWidget(_wrap(ServiceListCard(
      item: s,
      onOpen: () => opened++,
      onOpenProvider: () => provider++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text(s.providerName));
    await tester.pumpAndSettle();
    expect(provider, 1, reason: 'اسمُ المزوّد لم يفتح ملفَّه');
    expect(opened, 0, reason: 'اسمُ المزوّد فتح الخدمة');
  });

  testWidgets('**وزرُّ التفاصيل بخطّ التطبيق لا بمربّعات**', (tester) async {
    // **`textStyle` عارٍ في `styleFrom` يحلّ محلَّ أسلوب الثيمة كلِّه** —
    // ومعه عائلةُ الخطّ — فتُرسم الحروفُ العربيّةُ مربّعاتٍ بيضاء. وقد وقع
    // في زرّ «إعادة فتح» وخرج في لقطة.
    final s = _withCover;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    // **ويُسأل المحلولُ لا الخاصّيّة**: `styleFrom` يعيد
    // `WidgetStatePropertyAll(null)` حتى حين لا يُمرَّر نمطٌ — فسؤالُ
    // `textStyle` وحدَها لا يكون فارغاً أبداً، ويخضرّ الاختبارُ كاذباً.
    final button = tester.widget<FilledButton>(find.byKey(ValueKey('open-${s.id}')));
    expect(button.style?.textStyle?.resolve(<WidgetState>{}), isNull,
        reason: 'أسلوبٌ عارٍ يحلّ محلَّ أسلوب الثيمة — فتذهب عائلةُ الخطّ');
    final label = tester.widget<Text>(find.text('عرض التفاصيل'));
    expect(label.style?.fontFamily, isNull,
        reason: 'عائلةٌ مكتوبةٌ بيدٍ تتجاوز الثيمة');
  });

  testWidgets('**و«مميّز» تُقرأ على الصورة — قرصٌ لا إطارٌ ملوّن**',
      (tester) async {
    // **وإطارٌ كهرمانيٌّ بحرفٍ كهرمانيٍّ فوق قاعةٍ مضاءةٍ بالذهب يذوب فيها.**
    final s = demoServices.firstWhere((s) => s.providerIsFeatured);
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    expect(find.text('مميّز'), findsOneWidget);
    expect(find.byType(StatusBadge), findsNothing,
        reason: 'الشارةُ ما زالت إطاراً شفّافاً على الصورة');
  });
}
