// صورةُ صاحب الرأي في «آراء العملاء».
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد آراء العملاء صورة تظهر… صورة تجلبها لي من ملف شخصية حق العميل».
//
// ── ولم تكن الشاشةُ هي العطب ───────────────────────────────────────────────
//
// `class Review` لم يكن فيها حقلُ صورةٍ أصلاً، وقراءتُها كانت خمسةَ أعمدةٍ من
// جدول `reviews`. ولو أُضيف العمودُ لَما وصل: الصورةُ في `app_users`، وسياستُها
// «لا يرى حسابات غيره إطلاقاً»، وصفحةُ المزوّد يفتحها غيرُ صاحب الرأي أبداً.
// فمصدرُها الآن `api_provider_reviews` — و`supabase/tests/review_avatars.test.mjs`
// يقيس حدودَها في قاعدةٍ حقيقيّة. وهنا يُقاس ما يصل الشاشةَ منها.
//
// ── ولولا البديلُ لَما قيس شيء ─────────────────────────────────────────────
//
// `Api.avatarUrl` بلا سلّةٍ تعود بـ`null` أبداً، فكلُّ قرصٍ يرسم حرفاً وكسرٌ
// يمحو المسارَ لا يغيّر شيئاً يُرى. **وقد كُتب ضابطٌ سالبٌ لذلك من قبلُ فلم
// يسقط**، فأُصلح القياسُ بـ`avatarUrlOverride` لا الشيفرة.
//
// ── ولا يُسأل القرصُ عن اسمٍ يجاوره ────────────────────────────────────────
//
// وجودُ صورةٍ في الشجرة لا يعني أنّها صورةُ صاحب الرأي: سطرٌ يُنسخ ويبقى فيه
// `rows[0]` يُعطي كلَّ الآراء صورةَ أوّلِها. **فيُقرن كلُّ قرصٍ باسمِ صفّه.**
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/provider_public.dart';
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// يفتح صفحةَ المزوّد العامّة ثمّ تبويبَ «التقييمات».
Future<void> _openReviews(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
  await _settle(tester);
  await tester.tap(find.text('التقييمات'));
  await _settle(tester);
}

/// القرصُ الذي في صفّ هذا الاسم — **لا أيُّ قرصٍ في الشاشة**.
///
/// الصفحةُ فيها أقراصٌ أخرى (شعارُ المزوّد في رأسها)، والآراءُ ثلاثةٌ لكلٍّ
/// قرصُه. فيُصعد من الاسم إلى أقرب `Row` يحويه ثمّ يُنزل منه إلى قرصه.
ProviderAvatar _avatarOf(WidgetTester tester, String name) {
  final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
  return tester.widget<ProviderAvatar>(
    find.descendant(of: row, matching: find.byType(ProviderAvatar)),
  );
}

void main() {
  setUp(() {
    Api.avatarUrlOverride = (path) => 'https://example.invalid/$path';
  });
  tearDown(() => Api.avatarUrlOverride = null);

  test('**والمسارُ يُقرأ من صفّ الخادم**', () {
    // `Review.fromMap` هي البابُ الذي تدخل منه الصورةُ من `api_provider_reviews`.
    final r = Review.fromMap(const {
      'id': 'r9',
      'user_name': 'أحمد',
      'rating': 5,
      'comment': 'ممتاز',
      'created_at': '2026-06-01T00:00:00Z',
      'avatar_path': 'u9/avatar.jpg',
    });
    expect(r.avatarPath, 'u9/avatar.jpg');
  });

  test('وصفٌّ بلا صورةٍ لا يُسقط القراءة', () {
    // الدالّةُ تُرجع `''`، والجدولُ عند التراجع لا يُرجع الحقلَ إطلاقاً.
    final r = Review.fromMap(const {
      'id': 'r9',
      'user_name': 'أحمد',
      'rating': 5,
      'comment': 'ممتاز',
      'created_at': '2026-06-01T00:00:00Z',
    });
    expect(r.avatarPath, '');
  });

  testWidgets('**صورةُ صاحب الرأي تصل قرصَه**', (tester) async {
    await _openReviews(tester);

    expect(find.text('آراء العملاء'), findsOneWidget, reason: 'التبويبُ لم يُفتح');
    expect(_avatarOf(tester, 'أحمد الشرعبي').imageUrl,
        'https://example.invalid/demo-u1/avatar.jpg',
        reason: 'الصورةُ لم تصل القرص');
  });

  testWidgets('**وكلُّ قرصٍ صورةُ صاحبه لا صورةُ الأوّل**', (tester) async {
    await _openReviews(tester);

    // سطرٌ مربوطٌ بـ`rows[0]` يمرّ في الاختبار السابق ويسقط هنا.
    expect(_avatarOf(tester, 'سُمية القدسي').imageUrl,
        'https://example.invalid/demo-u2/avatar.jpg',
        reason: 'الآراءُ كلُّها تحمل صورةَ أوّلها');
  });

  testWidgets('ومن لم يرفع صورةً يبقى حرفُه', (tester) async {
    await _openReviews(tester);

    // **ولا يُرسم رابطٌ لمسارٍ فارغ**: `Image.network('')` أيقونةُ عطبٍ لا حرف.
    expect(_avatarOf(tester, 'خالد الحداد').imageUrl, isNull,
        reason: 'قرصُ من لا صورةَ له يطلب رابطاً');
  });
}
