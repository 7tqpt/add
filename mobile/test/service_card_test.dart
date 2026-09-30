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

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
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
      // **وفي قائمةٍ لا في سقّالةٍ فارغة:** البطاقةُ في `body` بلا قيدٍ
      // تمتدّ إلى قاع الشاشة، فيُقاس ارتفاعُ الشاشة ويُظنّ ارتفاعَ البطاقة.
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [child],
        ),
      ),
    ),
  ),
);

ServiceItem get _withCover => demoServices.firstWhere((s) => s.coverPath != null);
ServiceItem get _noCover => demoServices.firstWhere((s) => s.coverPath == null);

void main() {
  testWidgets('**والبطاقةُ صفٌّ قصير — مربّعٌ إلى جانب الاسم**', (tester) async {
    // **وهذا ما قاله صاحبُ المنصّة نصّاً**: «صار حجم البطاقة كبير جدن».
    // كان الغلافُ لوحاً بعرض البطاقة بارتفاع ‎١٦٨‎، فبلغت ‎٣٩٧‎ بكسلاً ولم
    // يظهر في الشاشة إلّا اثنتان ونصف. فاختار المربّعَ إلى جانب الاسم.
    //
    // **والارتفاعُ يُقاس لا يُوصف**: «قصيرة» كلمةٌ لا تسقط بكسر، والرقمُ
    // يسقط.
    final s = _withCover;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(Card));
    final cover = tester.getRect(find.byKey(ValueKey('cover-${s.id}')));

    expect(cover.width, ServiceListCard.coverSide,
        reason: 'ضلعُ الغلاف ليس الضلعَ المعلن');
    expect(cover.height, ServiceListCard.coverSide, reason: 'الغلافُ ليس مربّعاً');
    expect(cover.width, lessThan(card.width / 2),
        reason: 'الغلافُ يبتلع نصفَ البطاقة — عاد لوحاً لا مربّعاً');
    expect(card.height, lessThan(150),
        reason: 'البطاقةُ طويلةٌ (${card.height.round()} بكسل) — والمطلوبُ نحو ١٢٠');
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

  testWidgets('**والبطاقةُ كلُّها بابٌ — وتقول ذلك بحرفٍ في زاويتها**',
      (tester) async {
    // **وزرُّ «عرض التفاصيل» ذهب حين قُصّرت البطاقة** — اختار صاحبُ المنصّة
    // ذلك على بقائه. فبقي البابُ في البطاقة نفسِها، و«التفاصيل ›» تقول
    // للعين إنّها تُضغط. **وبلا هذا الحرف بابٌ لا يُرى.**
    final s = _withCover;
    var opened = 0;
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () => opened++)));
    await tester.pumpAndSettle();

    expect(find.text('التفاصيل'), findsOneWidget,
        reason: 'لا حرفَ يقول إنّ البطاقةَ تُضغط');
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget,
        reason: 'لا سهمَ مع الحرف');

    // **ويُقاس الفتحُ من ضغطةٍ على البطاقة نفسِها** لا من وجود الحرف.
    await tester.tap(find.text(s.title));
    await tester.pumpAndSettle();
    expect(opened, 1, reason: 'الضغطةُ على البطاقة لم تفتح الخدمة');
  });

  testWidgets('**وعلى جوالٍ بعرض ٣٢٠ لا تفيض — ويبقى السهمُ بابَها**',
      (tester) async {
    // **فاضت بسبعةَ عشرَ بكسلاً** وكشفها اختبارُ مرشِّح المحافظات: العربونُ
    // والتقييمُ و«التفاصيل ›» لا يسعها عمودٌ عرضُه ‎١٥٦‎. فتسقط الكلمةُ
    // على الضيّق — **ولا يسقط السهم**: بغيره بابٌ لا يُرى.
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = demoServices.firstWhere((x) => x.providerRating > 0);
    await tester.pumpWidget(_wrap(ServiceListCard(
      item: s,
      onOpen: () {},
      isFavourite: false,
      onToggleFavourite: () {},
      onOpenProvider: () {},
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'البطاقةُ تفيض على جوالٍ بعرض ٣٢٠');
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget,
        reason: 'ذهب السهمُ مع الكلمة — فلا شيءَ يقول إنّ البطاقةَ تُضغط');
  });

  testWidgets('**والقلبُ يحفظ ولا يفتح الخدمة**', (tester) async {
    // **وهذا يسقط بسهولة**: القلبُ داخل بطاقةٍ كلُّها تُضغط — فإن لم يكن له
    // سطحُه الخاصّ ذهبت الضغطةُ إلى البطاقة وفُتحت الخدمة.
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

  testWidgets('**والنطاقُ السعريُّ يظهر كاملاً لا مقصوصاً**', (tester) async {
    // **وهذا وقع فعلاً في أوّل رسمةٍ للبطاقة القصيرة**: حشرتُ التقييمَ في
    // سطر السعر، فضاق عمودُ النصّ إلى جانب المربّع وخرج «850,000 ر.ي –
    // 1,400…». فنزل التقييمُ إلى سطر العربون.
    //
    // **ولا يُسأل `didExceedMaxLines` هنا، وقد سألتُه فكذب**: خطُّ التطبيق
    // (IBM Plex Sans Arabic) لا يُحمَّل في هذا المجلّد، فيرسم الإطارُ بخطٍّ
    // بديلٍ كلُّ حرفٍ فيه مربّعٌ بعرض الحجم — فيطلب النطاقُ ‎٣٥٠‎ بكسلاً
    // بدل ‎١٨٠‎، ويخرج «مقصوصاً» في الاختبار وهو سليمٌ على الجهاز.
    //
    // **فيُقاس ما يملكه السطرُ لا ما رُسم فيه**: للسعر عرضُ العمود كلِّه.
    // ومن أعاد التقييمَ إلى سطره ضيّق عليه، فيسقط هذا مهما كان الخطّ.
    final s = demoServices.firstWhere((x) => x.priceTo != null);
    await tester.pumpWidget(_wrap(ServiceListCard(
      item: s,
      onOpen: () {},
      isFavourite: false,
      onToggleFavourite: () {},
      onOpenProvider: () {},
    )));
    await tester.pumpAndSettle();

    final price = formatMoneyRange(s.price, s.priceTo);
    final para = tester.renderObject<RenderParagraph>(find.text(price));
    // **وعرضُ العمود من العمود نفسِه**: `Expanded` يعطيه عرضاً محكماً فيكون
    // بقدر ما بقي بعد المربّع. (وكان يُقرأ من صفِّ العربون، فلمّا صار العربونُ
    // في صفٍّ داخليٍّ أضيقَ خرج المرجعُ أضيقَ من العمود واحمرّ الاختبارُ
    // والشيفرةُ سليمة.)
    final column = tester.getRect(find
        .ancestor(of: find.text(price), matching: find.byType(Column))
        .first);

    expect(para.constraints.maxWidth, closeTo(column.width, 1),
        reason: 'السعرُ يقاسم سطرَه غيرَه فيضيق عليه، وينقصّ طرفُ النطاق');
  });

  testWidgets('**و«مميّز» مصبوغةٌ تُقرأ على البطاقة البيضاء**', (tester) async {
    // **وكانت قرصاً أبيضَ حين كان الغلافُ صورةً تحتها**؛ وعلى بطاقةٍ بيضاء
    // يصير الأبيضُ على الأبيض. فصارت صبغةً كهرمانيّة.
    final s = demoServices.firstWhere((s) => s.providerIsFeatured);
    await tester.pumpWidget(_wrap(ServiceListCard(item: s, onOpen: () {})));
    await tester.pumpAndSettle();

    expect(find.text('مميّز'), findsOneWidget);
    final box = tester.widget<Container>(find.ancestor(
      of: find.text('مميّز'),
      matching: find.byType(Container),
    ).first);
    final colour = (box.decoration as BoxDecoration).color!;
    expect(colour.a, greaterThan(0.0),
        reason: 'أرضيّةُ الشارة شفّافةٌ — لا تُرى على الأبيض');
    expect(colour.a, lessThan(0.5), reason: 'الشارةُ مصمتةٌ تزاحم الاسم');
  });
}
