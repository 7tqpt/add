// غلافُ الملفّ الشخصيّ — صورةٌ يرفعها صاحبُها بنفسه.
//
// قال صاحبُ المنصّة: «في ملف الشخصي صورة الخلفيه خليه العميل او مقدم الخدمة
// يقدر يضيفها بنفسه نفس الفيس بوك»، ثمّ اختار من الصورتين المعروضتين عليه
// «(ب) غلافٌ مستقلٌّ فوق الرأس».
//
// **وأخطرُ ما يُقاس هنا أنّ الغائبَ ليس عطباً.** أكثرُ الناس لن يرفعوا
// غلافاً أبداً، فحالُ الفراغ هي الحالُ الغالبة: يجب أن تبقى الرأسَ النبيذيَّ
// كما كان — لا مربّعاً رماديّاً ولا أيقونةَ صورةٍ مكسورة.
//
// **وثانيها أنّ الاسمَ صار على البياض.** الرأسُ كان نبيذيّاً وحبرُه أبيض،
// فلمّا صار ما تحت الغلاف ورقةً بيضاء وجب أن ينقلب الحبر — وإلّا خرج أبيضُ
// على أبيض: اسمٌ لا يُقرأ في أوّل شاشةٍ يفتحها صاحبُ الحساب.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/provider_profile.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/ui/kit.dart';

const _statusBar = 44.0;
const _cameraKey = ValueKey('cover-edit');
const _avatarKey = ValueKey('test-avatar');

Widget _wrap(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: const MediaQueryData(padding: EdgeInsets.only(top: _statusBar)),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  ),
);

Widget _header({String? coverUrl, VoidCallback? onEditCover, bool coverBusy = false}) =>
    ProfileHeader(
      coverUrl: coverUrl,
      onEditCover: onEditCover,
      coverBusy: coverBusy,
      avatar: const SizedBox(
        key: _avatarKey,
        width: profileAvatarSize,
        height: profileAvatarSize,
      ),
      title: 'أيمن الحُميري',
      subtitle: '+967771234567',
      badge: 'عريس',
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

void main() {
  group('الرأسُ نفسُه', () {
    testWidgets('**ومن لا غلافَ له يبقى رأسُه كما كان**', (tester) async {
      // لا صورةَ في الشجرة أصلاً — لا صورةٌ تُحمَّل فتُخفق فتُخفى.
      _phone(tester);
      await tester.pumpWidget(_wrap(_header()));
      await _settle(tester);

      expect(find.byType(Image), findsNothing);
      expect(find.text('أيمن الحُميري'), findsOneWidget);
      expect(find.text('عريس'), findsOneWidget);
    });

    testWidgets('ومن رفع غلافاً يُرفع غلافُه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(_header(coverUrl: 'https://example.test/u1/cover.jpg')),
      );
      await _settle(tester);

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('**والقرصُ يطلّ على حافّة الغلاف — وهو شكلُ فيسبوك**', (tester) async {
      // **والمقيسُ موضعُه بالبكسل لا وجودُه.** قرصٌ تحت الشريط كلِّه شكلٌ
      // آخر، وقرصٌ فوقه كلِّه شكلٌ ثالث. والذي اختاره صاحبُ المنصّة أن
      // يقطع القرصُ الحافّةَ فيقع نصفُه في الصورة ونصفُه في البياض.
      _phone(tester);
      await tester.pumpWidget(_wrap(_header()));
      await _settle(tester);

      final band = _statusBar + ProfileHeader.coverBand;
      final disc = tester.getRect(find.byKey(_avatarKey));
      expect(disc.top, lessThan(band), reason: 'القرصُ كلُّه تحت الغلاف');
      expect(disc.bottom, greaterThan(band), reason: 'القرصُ كلُّه في الغلاف');
    });

    testWidgets('**والاسمُ حبرٌ داكنٌ على البياض لا أبيضُ على أبيض**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(_header()));
      await _settle(tester);

      final title = tester.widget<Text>(find.text('أيمن الحُميري'));
      expect(title.style?.color, AppColors.ink);
      final phone = tester.widget<Text>(find.text('+967771234567'));
      expect(phone.style?.color, AppColors.muted);
    });

    testWidgets('**والاسمُ تحت الغلاف لا فوقه**', (tester) async {
      // ولو بقي في الشريط لَوقع الحبرُ الداكنُ على صورةٍ داكنة.
      _phone(tester);
      await tester.pumpWidget(_wrap(_header()));
      await _settle(tester);

      final band = _statusBar + ProfileHeader.coverBand;
      expect(tester.getRect(find.text('أيمن الحُميري')).top, greaterThan(band));
    });
  });

  group('زرُّ التغيير', () {
    testWidgets('**ولا زرَّ في رأسٍ لا يملك رفعاً**', (tester) async {
      // زرٌّ يُضغط فلا يقع شيءٌ أسوأُ من غيابه.
      _phone(tester);
      await tester.pumpWidget(_wrap(_header()));
      await _settle(tester);
      expect(find.byKey(_cameraKey), findsNothing);
      expect(find.text('تغيير الغلاف'), findsNothing);
    });

    testWidgets('ويُعرض لمن يملكه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(_header(onEditCover: () {})));
      await _settle(tester);
      expect(find.byKey(_cameraKey), findsOneWidget);
      expect(find.text('تغيير الغلاف'), findsOneWidget);
    });

    testWidgets('ويُنادى حين يُضغط', (tester) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_wrap(_header(onEditCover: () => taps++)));
      await _settle(tester);
      await tester.tap(find.byKey(_cameraKey));
      await _settle(tester);
      expect(taps, 1);
    });

    testWidgets('**ولا يُضغط مرّتين والرفعُ جارٍ**', (tester) async {
      // ضغطتان ترفعان مرّتين على شبكةٍ يمنية — والثانيةُ تكتب فوق الأولى
      // وقد تسبقها فيبقى القديم.
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(_wrap(_header(onEditCover: () => taps++, coverBusy: true)));
      await _settle(tester);

      expect(find.text('جارٍ الرفع…'), findsOneWidget);
      await tester.tap(find.byKey(_cameraKey), warnIfMissed: false);
      await _settle(tester);
      expect(taps, 0);
    });

    testWidgets('**والزرُّ في الجهة المقابلة للقرص**', (tester) async {
      // القرصُ يطلّ على الحافّة نفسِها، فزرٌّ بجانبه يختفي تحته — وقد اختفى
      // فعلاً في أوّل رسمٍ للمقترح.
      _phone(tester);
      await tester.pumpWidget(_wrap(_header(onEditCover: () {})));
      await _settle(tester);

      final disc = tester.getRect(find.byKey(_avatarKey));
      final button = tester.getRect(find.byKey(_cameraKey));
      final overlap = button.left < disc.right && disc.left < button.right;
      expect(overlap, isFalse, reason: 'الزرُّ يتراكب مع القرص');
    });
  });

  group('الشاشتان', () {
    setUp(demoResetProfile);
    tearDown(demoResetProfile);

    testWidgets('**وحسابُ العميل يرفع غلافاً**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AccountScreen(session: _customer())));
      await tester.pumpAndSettle();
      expect(find.byKey(_cameraKey), findsOneWidget);
    });

    testWidgets('**وملفُّ المزوّد كذلك**', (tester) async {
      _phone(tester);
      demoBecomeProvider(
        businessName: 'قاعة التاج',
        governorate: 'أمانة العاصمة',
        bio: 'قاعةٌ لأعراس صنعاء',
      );
      await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
      await tester.pumpAndSettle();
      expect(find.byKey(_cameraKey), findsOneWidget);
    });

    testWidgets('**وسطرُ الحال العالقة يُقرأ على البياض**', (tester) async {
      // كان أبيضَ على الرأس النبيذيّ. ولمّا صار ما تحت الغلاف ورقةً بيضاء
      // خرج أبيضُ على أبيض — وهو السطرُ الذي يقول لصاحب القاعة إنّ طلبَه
      // لم يُقبل بعدُ وإنّه لن يستقبل حجزاً واحداً.
      _phone(tester);
      demoBecomeProvider(
        businessName: 'قاعة التاج',
        governorate: 'أمانة العاصمة',
        bio: 'قاعةٌ لأعراس صنعاء',
      );
      await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
      await tester.pumpAndSettle();

      final note = tester.widget<Text>(
        find.textContaining('طلبك قيد المراجعة', skipOffstage: false),
      );
      expect(note.style?.color, isNot(Colors.white));
      expect(note.style?.color, AppColors.ink2);
    });
  });

  group('صفحةُ المزوّد العامّة', () {
    test('**وغلافُها يُقرأ من الصفّ لا يُرسم ثابتاً**', () {
      // **ويُسأل الملفُّ نفسُه لا الشجرة.** الوضعُ التجريبيُّ لا سلّةَ له:
      // `Api.avatarUrl` تعيد `null` دائماً بلا Supabase، فالصفحةُ تعرض
      // التدرّجَ في كلّ حال — ويمرّ اختبارٌ بالشجرة سواءٌ قُرئ العمودُ أو
      // بقي الغلافُ تدرّجاً مرسوماً كما كان. وهي الحيلةُ نفسُها التي لزمت
      // في «شارك التطبيق».
      final src = File('lib/src/screens/provider_public.dart').readAsStringSync();
      expect(
        src,
        contains('Api.avatarUrl(p.coverPath)'),
        reason: 'الصفحةُ لا تقرأ عمودَ الغلاف',
      );
      expect(src, contains('_CoverArt'));
    });

    testWidgets('**ومن لا غلافَ له يبقى تدرّجُه بقرصيه**', (tester) async {
      // الحالُ الغالبة — ولا مربّعَ رماديٌّ ولا صورةٌ مكسورة.
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const PublicProviderScreen(providerId: 'p1', name: 'قاعة التاج')),
      );
      await tester.pumpAndSettle();
      expect(find.text('قاعة التاج'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ما يصل الخادم', () {
    setUp(demoResetProfile);
    tearDown(demoResetProfile);

    test('**ولا يُسأل الحقلُ عمّا فيه بل يُسأل ما وصل**', () async {
      // الرأسُ يعرض ما يُمرَّر إليه سواءٌ حُفظ أو لم يُحفظ. فيُقرأ الملفُّ
      // بعد الحفظ من حيث يُقرأ في التطبيق.
      final me = await Api.myProfile();
      expect(me!.coverPath, isEmpty);

      await Api.updateProfile(fullName: me.fullName, coverPath: 'u1/cover.jpg');
      final after = await Api.myProfile();
      expect(after!.coverPath, 'u1/cover.jpg');
    });

    test('**وحفظُ الاسم وحدَه لا يمحو الغلاف**', () async {
      // `coalesce` في الدالّة، ومثلُها في الوضع التجريبيّ — ولو افترقا
      // لاختبرتُ سلوكاً لا يقع على القاعدة.
      final me = await Api.myProfile();
      await Api.updateProfile(fullName: me!.fullName, coverPath: 'u1/cover.jpg');
      await Api.updateProfile(fullName: 'أيمن الحُميري');
      expect((await Api.myProfile())!.coverPath, 'u1/cover.jpg');
    });

    test('**وغلافُ المزوّد يصل صفَّه**', () async {
      demoBecomeProvider(
        businessName: 'قاعة التاج',
        governorate: 'أمانة العاصمة',
        bio: 'قاعةٌ لأعراس صنعاء',
      );
      final p = await Api.providerProfile('demo-provider');
      await Api.updateProviderProfile(
        providerId: p!.id,
        coverPath: 'u1/provider_cover.jpg',
      );
      expect(
        (await Api.providerProfile('demo-provider'))!.coverPath,
        'u1/provider_cover.jpg',
      );
    });

    test('**وثلاثةُ أسماءٍ لا اسمٌ واحد**', () async {
      // كلُّها في مجلّد صاحب الحساب و`upsert` يكتب فوق ما وجد. فلو تشاركت
      // اسماً لَمحا رفعُ الغلاف شعارَ صاحبه — أو صورتَه — بلا سؤال.
      const id = 'u1';
      final avatar = await Api.uploadAvatar(
        authUserId: id,
        fileName: 'a.jpg',
        bytes: Uint8List(0),
      );
      final cover = await Api.uploadCover(
        authUserId: id,
        fileName: 'a.jpg',
        bytes: Uint8List(0),
      );
      final logo = await Api.uploadProviderLogo(
        authUserId: id,
        fileName: 'a.jpg',
        bytes: Uint8List(0),
      );
      final providerCover = await Api.uploadProviderCover(
        authUserId: id,
        fileName: 'a.jpg',
        bytes: Uint8List(0),
      );

      expect({avatar, cover, logo, providerCover}.length, 4, reason: 'رفعٌ يكتب فوق رفع');
      // وكلُّها في مجلّده هو — وسياسةُ السلّة تحصر الكتابة فيه.
      for (final p in [avatar, cover, logo, providerCover]) {
        expect(p, startsWith('$id/'));
      }
    });
  });
}
