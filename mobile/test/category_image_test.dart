// صورةُ القسم في بطاقته.
//
// **وما يُقاس هنا هو السقوطُ الرشيق أكثرَ من الصورة نفسها.** الشاشةُ الأولى
// اثنتا عشرة بطاقة، وثلاثةُ أحوالٍ تقع فيها ولا يقع الرابعُ إلّا على جهاز:
//
//   ١. لا صورةَ بعدُ — وهو الحالُ يومَ التشغيل نفسه، لا حالٌ نادرة.
//   ٢. صورةٌ لا تصل — شبكةٌ يمنيّةٌ تنقطع.
//   ٣. قاعدةٌ لم يُشغَّل عليها الملفُّ بعد — فلا عمودَ أصلاً.
//
// وفي الثلاثة تبقى الأيقونة. **ولا يُقاس رسمُ صورةٍ حقيقيّة**: لا شبكةَ في
// `flutter test`، وذاك يُجرَّب على جهاز.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/kit.dart';

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
    child: Scaffold(body: Center(child: child)),
  ),
);

Widget _card({String? imageUrl}) => CategoryCard(
  label: 'القاعات والخيام',
  icon: Icons.meeting_room_outlined,
  active: false,
  imageUrl: imageUrl,
  onTap: () {},
);

void main() {
  // ==========================================================================
  //  النموذج
  // ==========================================================================

  group('قراءةُ الصفّ', () {
    test('**قاعدةٌ بلا عمودٍ تُقرأ فراغاً لا NULL**', () {
      // وهي القاعدةُ التي لم يُشغَّل عليها `category_images.sql` بعد. ولو
      // قُرئت NULL لَاحتاجت كلُّ شاشةٍ فحصاً، ولو رُميت لَسقطت الشاشة الأولى.
      final c = ServiceCategory.fromMap(
          {'id': 'c1', 'name': 'القاعات', 'slug': 'halls'});
      expect(c.imagePath, '');
    });

    test('وصفٌّ فيه مسارٌ يُقرأ كما هو', () {
      final c = ServiceCategory.fromMap({
        'id': 'c1', 'name': 'القاعات', 'slug': 'halls',
        'image_path': 'halls/1699.jpg',
      });
      expect(c.imagePath, 'halls/1699.jpg');
    });

    test('وعمودٌ فارغٌ صراحةً كذلك', () {
      final c = ServiceCategory.fromMap({
        'id': 'c1', 'name': 'القاعات', 'slug': 'halls', 'image_path': '',
      });
      expect(c.imagePath, '');
    });
  });

  // ==========================================================================
  //  البطاقة
  // ==========================================================================

  testWidgets('**بلا صورةٍ تبقى الأيقونة**', (tester) async {
    // وهذا هو الحالُ يومَ تشغيل الملفّ: العمودُ موجودٌ ولا صورةَ رُفعت بعد.
    // فلو اختفت الأيقونةُ لَصارت الشاشةُ الأولى اثنتي عشرة دائرةً فارغة.
    await tester.pumpWidget(_wrap(_card()));
    await tester.pump();

    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('**ومسارٌ فارغٌ لا يُبنى له ودجت صورةٍ أصلاً**', (tester) async {
    // **والأيقونةُ وحدها لا تكفي دليلاً هنا:** لو مُرِّر الفراغُ إلى
    // `Image.network` لَفشل فوراً وعادت الأيقونةُ كذلك — فيمرّ الاختبارُ وهو
    // لا يفرّق. فيُسأل عن **وجود الودجت** لا عن الأيقونة: نصٌّ فارغٌ يُقرأ
    // «لا صورة»، فلا يُبنى شيءٌ ولا يُطلب من الشبكة شيء.
    await tester.pumpWidget(_wrap(_card(imageUrl: '')));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
  });

  testWidgets('**وصورةٌ لا تصل تعود إلى الأيقونة**', (tester) async {
    // شبكةٌ تنقطع، أو ملفٌّ حُذف من السلّة والمسارُ باقٍ في الصفّ. ومن رأى
    // اثنتي عشرة أيقونةَ خطأٍ حكم على التطبيق كلِّه.
    await tester.pumpWidget(_wrap(_card(imageUrl: 'https://example.invalid/a.jpg')));
    await tester.pump();
    for (var n = 0; n < 6; n++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget,
        reason: 'لم تعد إلى الأيقونة بعد فشل التحميل');
  });

  testWidgets('وأثناء التحميل تبقى الأيقونة لا دائرةٌ فارغة', (tester) async {
    await tester.pumpWidget(_wrap(_card(imageUrl: 'https://example.invalid/a.jpg')));
    await tester.pump();

    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
  });

  testWidgets('**ومقاسُ البطاقة لا يتغيّر بوجود صورة**', (tester) async {
    // ولو تغيّر لَانكسرت الشبكةُ بين قسمٍ ذي صورةٍ وقسمٍ بلا صورة — وهو
    // الحالُ الغالبُ في أوّل يوم.
    await tester.pumpWidget(_wrap(_card()));
    await tester.pump();
    final without = tester.getSize(find.byType(CategoryCard));

    await tester.pumpWidget(_wrap(_card(imageUrl: 'https://example.invalid/a.jpg')));
    await tester.pump();
    final with_ = tester.getSize(find.byType(CategoryCard));

    expect(with_, without);
  });

  testWidgets('**والصورةُ داخل دائرةِ الأيقونة نفسِها — ٣٦ في ٣٦**',
      (tester) async {
    // **وهذا ما يحرس المقاس فعلاً.** الاختبارُ فوقه لا يعضّ لو كُبّرت الصورةُ
    // وحدها: الحاويةُ ٣٦ ثابتةٌ فتقصّها. والذي يكسر الشبكةَ حقّاً هو أن
    // تُوضع الصورةُ خارج تلك الحاوية — فيُقاس أنّها بداخلها.
    await tester.pumpWidget(_wrap(_card(imageUrl: 'https://example.invalid/a.jpg')));
    await tester.pump();

    final glyph = find.ancestor(
      of: find.byIcon(Icons.meeting_room_outlined),
      matching: find.byType(ClipOval),
    );
    expect(glyph, findsOneWidget, reason: 'الصورةُ ليست في دائرةِ الأيقونة');
    expect(tester.getSize(glyph), const Size(36, 36));
  });
}
