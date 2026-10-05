// «تقديم خدمة» — منسدلتان متطابقتان.
//
// **والعلّةُ أنّ النموذجَ كان يمتدّ صفحتين.** المحافظاتُ عشرون شريحةً
// والأقسامُ ستّ، فتُدفع بها بقيّةُ النموذج وزرُّ الإرسال تحت الطيّة —
// ومن فتح الشاشةَ لا يرى كم بقي عليه.
//
// ثمّ قرّر صاحبُ المنصّة أنّ **المزوّد لا يعمل في أكثر من قسم**: القاعةُ
// قاعةٌ ولا تطبخ. فسقط الاختيارُ المتعدّدُ بورقته ومربّعاته وزرِّ «تمّ»،
// وصار الحقلان منسدلتين متطابقتين.
//
// **والقسمُ غيرُ الخدمة:** المزوّدُ يعرض داخلَ قسمه باقاتٍ عدّة في
// `provider_services` — وتلك لم تُمسّ، ومنعُها إلى واحدةٍ يكسر المنصّة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/become_provider.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:flutter/rendering.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(BecomeProviderScreen(session: _session())));
  await _settle(tester);
}

void main() {
  group('تقديم خدمة', () {
    testWidgets('**ولا جدارَ شرائحَ في النموذج**', (tester) async {
      // وهي علّةُ الباب: عشرون شريحةً للمحافظة وستٌّ للأقسام تدفع زرَّ
      // الإرسال تحت الطيّة.
      await _open(tester);
      expect(find.byType(PickChip), findsNothing,
          reason: 'الشرائحُ عادت إلى النموذج');
    });

    testWidgets('**والمحافظةُ منسدلةٌ فيها كلُّ المحافظات**', (tester) async {
      await _open(tester);
      // **وبمفتاحه لا بنوعه:** في الشاشة منسدلتان منذ صار القسمُ واحداً،
      // فسؤالٌ بالنوع يلتقط أوّلَهما في الشجرة ويظنّه المحافظة.
      final field = find.byKey(const ValueKey('governorate-field'));
      expect(field, findsOneWidget);

      await tester.tap(field);
      await _settle(tester);

      // **ويُقاس عددُ ما فُتح لا وجودُ القائمة.** منسدلةٌ فارغةٌ تُفتح ولا
      // تُظهر شيئاً، ومن فتحها ظنّ الشاشةَ عاطلة.
      for (final g in demoGovernorates) {
        expect(find.text(g.name), findsWidgets, reason: '${g.name} ليست في القائمة');
      }
    });

    testWidgets('**والقسمُ منسدلةٌ واحدةٌ لا ورقةَ اختيارٍ متعدّد**',
        (tester) async {
      // **وهذه هي القاعدةُ الجديدة.** كان حقلاً يفتح ورقةً بمربّعاتٍ
      // يُختار منها ما شاء. فصار قسماً واحداً.
      await _open(tester);
      expect(find.byKey(const ValueKey('category-field')), findsOneWidget);
      expect(find.text('اختر قسمك'), findsOneWidget);

      // ولا ورقةَ ولا مربّعاتِ اختيارٍ في الشاشة كلِّها.
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      expect(find.byType(CheckboxListTile), findsNothing,
          reason: 'عاد الاختيارُ المتعدّد');
      expect(find.widgetWithText(FilledButton, 'تمّ'), findsNothing);
    });

    testWidgets('**والحقلان منسدلتان — لا شكلان مختلفان**', (tester) async {
      // حقلان متجاوران يفتحان سطحين مختلفين فوضى تُقرأ قبل أن تُسمّى.
      await _open(tester);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    });

    testWidgets('**وأقسامُ القاعدة كلُّها في القائمة**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      for (final c in demoCategories) {
        expect(find.text(c.name), findsWidgets, reason: '${c.name} ليست فيها');
      }
    });

    testWidgets('**والقسمُ المختارُ هو ما يصل الخادم**', (tester) async {
      // **ولا يُسأل الحقلُ عمّا فيه — فهو يكذب.**
      // `DropdownButtonFormField` حقلُ نموذجٍ يحتفظ باختياره داخلَ نفسه،
      // فيعرضه للعين ولو لم يصل `onChanged` شيئاً.
      //
      // ويُقاس **اسمُ القسم** لا معرّفُه: وضعُ الاسم في `value` بدل `id`
      // يمرّ في العين ويصل الخادمَ نصّاً لا `uuid`، فيُرفض الطلب.
      demoProviderProfile = null;
      demoProviderCategoryId = null;
      addTearDown(() {
        demoProviderProfile = null;
        demoProviderCategoryId = null;
      });

      await _open(tester);
      await tester.enterText(find.byKey(const ValueKey('apply-name')), 'قاعة التجربة');
      await tester.enterText(find.byKey(const ValueKey('apply-phone')), '770000000');
      await tester.enterText(find.byKey(const ValueKey('apply-bio')), 'قاعةٌ لخمسمئة ضيف');

      await tester.tap(find.byKey(const ValueKey('governorate-field')));
      await _settle(tester);
      await tester.tap(find.text(demoGovernorates[1].name).last);
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories[1].name).last);
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);

      expect(demoProviderProfile, isNotNull, reason: 'لم يُرسَل الطلبُ أصلاً');
      expect(demoProviderProfile!.governorate, demoGovernorates[1].name);
      // **والمعرّفُ لا الاسم.** لو وُضع `c.name` في `value` لَمرّ في العين
      // ووصل هنا نصّاً عربيّاً — وهو ما تردّه القاعدةُ ولا يردّه وضعُ العرض.
      expect(demoProviderCategoryId, demoCategories[1].id,
          reason: 'وصل الخادمَ غيرُ معرّفِ القسم');
    });

    testWidgets('**ولا يُرسَل طلبٌ بلا قسم**', (tester) async {
      // الخادمُ يقبله بلا قسمٍ فيصير مزوّداً لا يظهر في أيّ دليل — وهو
      // أسوأُ من رفضٍ ظاهر.
      demoProviderProfile = null;
      addTearDown(() => demoProviderProfile = null);

      await _open(tester);
      await tester.enterText(find.byKey(const ValueKey('apply-name')), 'قاعة التجربة');
      await tester.enterText(find.byKey(const ValueKey('apply-phone')), '770000000');
      await tester.enterText(find.byKey(const ValueKey('apply-bio')), 'قاعةٌ لخمسمئة ضيف');
      await tester.tap(find.byKey(const ValueKey('governorate-field')));
      await _settle(tester);
      await tester.tap(find.text(demoGovernorates[1].name).last);
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);

      expect(demoProviderProfile, isNull, reason: 'مرّ طلبٌ بلا قسم');
      expect(find.textContaining('وقسمك'), findsOneWidget);
    });

    // ── على صورة صاحب المنصّة ────────────────────────────────────────────
    //
    // «خلي الحقول فارغه مثل اسم المنشاة ورقم التوصل» — ثمّ اختار (أ): تصميمُه
    // كلُّه، والحقولُ فارغة.

    testWidgets('**الحقولُ فارغةٌ عند الفتح، والرماديُّ فيها اسمُها لا مثال**', (tester) async {
      await _open(tester);
      for (final key in ['apply-name', 'apply-phone', 'apply-bio']) {
        final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
        expect(field.controller!.text, isEmpty, reason: '$key ليس فارغاً');
      }
      String? hint(String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).decoration!.hintText;
      expect(hint('apply-name'), 'اسم المنشأة');
      expect(hint('apply-phone'), '7XX XXX XXX');
      expect(hint('apply-bio'), 'عرّف العرسان بخدماتك');
      // **ولا مثالَ يُقرأ كأنّه مكتوب** — وهو ما كان: «قاعة التاج».
      expect(find.text('قاعة التاج'), findsNothing);
      expect(find.text('اختر محافظتك'), findsOneWidget);
      expect(find.text('اختر قسمك'), findsOneWidget);
    });

    testWidgets('**وعنوانٌ فوق كلّ حقلٍ بنجمةٍ ذهبيّة**', (tester) async {
      await _open(tester);
      for (final (label, field) in [
        ('اسم المنشأة', 'apply-name'),
        ('رقم التواصل', 'apply-phone'),
        ('نبذة عن الخدمة', 'apply-bio'),
        ('المحافظة', 'governorate-field'),
        ('القسم الذي تعمل فيه', 'category-field'),
      ]) {
        final title = find.byWidgetPredicate((w) =>
            w is RichText && w.text.toPlainText() == '$label *');
        expect(title, findsOneWidget, reason: 'لا عنوانَ بنجمةٍ لـ$label');
        final t = tester.getRect(title), f = tester.getRect(find.byKey(ValueKey(field)));
        expect(t.bottom, lessThanOrEqualTo(f.top + 1), reason: '$label ليس فوق حقله');
      }
    });

    testWidgets('**والرقمُ يصل الخادمَ بمفتاحه** — +967 بجانب الحقل', (tester) async {
      // **ما وصل لا ما في الحقل:** الحقلُ فيه «770000000»، والواصلُ مجموعُه
      // إلى المفتاح — كما في «أكمل ملفك».
      demoProviderProfile = null;
      demoProviderPhone = null;
      addTearDown(() {
        demoProviderProfile = null;
        demoProviderPhone = null;
      });
      await _open(tester);
      expect(find.byKey(const ValueKey('dial-picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('dial-label')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('apply-name')), 'قاعة التجربة');
      await tester.enterText(find.byKey(const ValueKey('apply-phone')), '770000000');
      await tester.enterText(find.byKey(const ValueKey('apply-bio')), 'قاعةٌ لخمسمئة ضيف');
      await tester.tap(find.byKey(const ValueKey('governorate-field')));
      await _settle(tester);
      await tester.tap(find.text(demoGovernorates[1].name).last);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories[1].name).last);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);
      expect(demoProviderPhone, '+967770000000');
      expect(demoProviderProfile?.bio, 'قاعةٌ لخمسمئة ضيف');
    });

    testWidgets('**و«دولة أخرى» تطلب المفتاحَ مكتوباً** — لا يُنسب الرقمُ إلى اليمن', (tester) async {
      demoProviderProfile = null;
      addTearDown(() => demoProviderProfile = null);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('dial-picker')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('dial-other')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('dial-label')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('apply-name')), 'قاعة التجربة');
      await tester.enterText(find.byKey(const ValueKey('apply-phone')), '770000000');
      await tester.enterText(find.byKey(const ValueKey('apply-bio')), 'قاعةٌ لخمسمئة ضيف');
      await tester.tap(find.byKey(const ValueKey('governorate-field')));
      await _settle(tester);
      await tester.tap(find.text(demoGovernorates[1].name).last);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories[1].name).last);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);
      expect(demoProviderProfile, isNull, reason: 'نُسب رقمٌ بلا مفتاحٍ إلى اليمن');
      expect(find.textContaining('مفتاح الدولة'), findsOneWidget);
    });

    testWidgets('**والنبذةُ مطلوبةٌ كالبقيّة** — عليها نجمة', (tester) async {
      demoProviderProfile = null;
      addTearDown(() => demoProviderProfile = null);
      await _open(tester);
      await tester.enterText(find.byKey(const ValueKey('apply-name')), 'قاعة التجربة');
      await tester.enterText(find.byKey(const ValueKey('apply-phone')), '770000000');
      await tester.tap(find.byKey(const ValueKey('governorate-field')));
      await _settle(tester);
      await tester.tap(find.text(demoGovernorates[1].name).last);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('category-field')));
      await _settle(tester);
      await tester.tap(find.text(demoCategories[1].name).last);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'إرسال الطلب'));
      await _settle(tester);
      expect(demoProviderProfile, isNull, reason: 'مرّ طلبٌ بلا نبذة');
      expect(find.textContaining('نبذةً عن خدمتك'), findsOneWidget);
    });

    testWidgets('**وبطاقةُ الرأس: سطرٌ واحدٌ ومتجرٌ وغصنٌ من صورته**', (tester) async {
      // جوالٌ ضيّق: ‎٣٢٠‎ نقطة.
      tester.view.physicalSize = const Size(960, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(BecomeProviderScreen(session: _session())));
      await _settle(tester);
      expect(find.text('سجّل منشأتك'), findsOneWidget);
      final line = tester.renderObject<RenderParagraph>(find.byKey(const ValueKey('apply-head-line')));
      expect(line.maxLines, 1);
      expect(line.didExceedMaxLines, isFalse, reason: 'قُصّ آخرُ السطر');
      final head = tester.getRect(find.byKey(const ValueKey('apply-head')));
      for (final (key, asset) in [('apply-store', 'apply_store'), ('apply-sprig', 'apply_sprig')]) {
        final art = tester.widget<Image>(find.byKey(ValueKey(key)));
        expect((art.image as AssetImage).assetName, 'assets/brand/$asset.png');
        expect(head.contains(tester.getRect(find.byKey(ValueKey(key))).center), isTrue, reason: '$key خارجَ البطاقة');
      }
      // **والمتجرُ في الطرف الأيسر، والعنوانُ في الأيمن** — كما في صورته.
      expect(tester.getRect(find.byKey(const ValueKey('apply-store'))).center.dx,
          lessThan(tester.getRect(find.text('سجّل منشأتك')).left));
    });

    testWidgets('**وطائرةُ الورق يسارَ «إرسال الطلب»**', (tester) async {
      await _open(tester);
      final mark = tester.getRect(find.byKey(const ValueKey('apply-send-mark')));
      final text = tester.getRect(find.text('إرسال الطلب'));
      expect(mark.right, lessThanOrEqualTo(text.left), reason: 'الطائرةُ ليست يسارَ النصّ');
      expect((mark.center.dy - text.center.dy).abs(), lessThan(6));
    });

    testWidgets('ولا يفيض النموذجُ بخطّ الجهاز الكبير', (tester) async {
      for (final scale in [1.3, 2.0]) {
        _phone(tester, height: 6000);
        await tester.pumpWidget(_wrap(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: BecomeProviderScreen(session: _session()),
        )));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'فاض عند $scale');
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
      }
    });
  });

  group('محفظة الحساب', () {
    testWidgets('**والوسيلةُ منسدلةٌ بعنوانها لا شرائحُ بلا عنوان**',
        (tester) async {
      // كانت الشرائحُ العنصرَ الوحيدَ في الورقة بلا عنوان، وتحتها حقلان
      // بعنوانيهما — فيُقرأ الصفُّ الأوّلُ زينةً لا سؤالاً.
      _phone(tester);
      await tester.pumpWidget(_wrap(const PaymentMethodsScreen()));
      await _settle(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'وسيلة جديدة'));
      await _settle(tester);

      expect(find.byKey(const ValueKey('wallet-method')), findsOneWidget);
      expect(find.byType(PickChip), findsNothing);
      // والعنوانُ مكتوب.
      expect(find.text('الوسيلة'), findsWidgets);
    });
  });
}
