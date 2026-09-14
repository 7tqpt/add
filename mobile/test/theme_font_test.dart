// خطُّ العلامة في الأزرار وشريطِ التنقّل.
//
// ── العلّة التي يحرسها هذا الملفّ ────────────────────────────────────────────
//
// `buildTheme()` تضع `fontFamily: brandFont` على الثيمة كلِّها، وكانت تضع في
// ثلاثة مواضعَ نمطَ نصٍّ فيه `fontFamilyFallback` **بلا `fontFamily`**:
// `filledButtonTheme` و`outlinedButtonTheme` و`navigationBarTheme`.
//
// **ونمطُ الزرّ لا يرث عائلةَ الثيمة** — يُستعمل كما هو. فصارت العائلةُ
// الأولى عائلةَ النظام، وخطُّ العلامة يهبط إلى الاحتياط.
//
// **وما كان يُرى من ذلك ليس الحروفَ بل الفراغات.** الحروفُ العربيّةُ لا
// يملكها خطُّ النظام فتسقط إلى خطّ العلامة وتخرج صحيحة؛ **والمسافةُ بين
// الكلمات (U+0020) يملكها** فلا تسقط. فكانت الكلماتُ بخطٍّ والفراغاتُ بينها
// بخطٍّ آخر — وهو الاتّساعُ الذي كان يُرى في كلّ زرٍّ في التطبيق. والشرطةُ
// «—» لا يملكها خطُّ النظام كذلك، فكانت تخرج مربّعاً أسود.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';

/// النمطُ المحلولُ لحالةٍ خاملة — وهو ما يُرسم به النصُّ فعلاً.
TextStyle? _resolve(WidgetStateProperty<TextStyle?>? p) => p?.resolve({});

void main() {
  group('العائلةُ مذكورةٌ لا متروكةٌ للاحتياط', () {
    // **ويُسأل النمطُ المحلولُ لا الشيفرةُ المكتوبة.** ما يُرسم به النصُّ هو
    // ما تعطيه `resolve`، وقد تُبدَّل الطبقاتُ فوقه.

    test('**في الأزرار المملوءة**', () {
      final style = _resolve(buildTheme().filledButtonTheme.style?.textStyle);
      expect(style?.fontFamily, brandFont,
          reason: 'الزرُّ يسقط إلى خطّ النظام، فتتّسع الفراغاتُ بين كلماته');
    });

    test('وفي الأزرار المحاطة', () {
      final style = _resolve(buildTheme().outlinedButtonTheme.style?.textStyle);
      expect(style?.fontFamily, brandFont);
    });

    test('**وفي شريط التنقّل السفليّ** — وهو في كلّ شاشة', () {
      final style = _resolve(buildTheme().navigationBarTheme.labelTextStyle);
      expect(style?.fontFamily, brandFont);
    });

    test('والاحتياطُ يبقى خلفها', () {
      // النسخُ يغطّي ما لا يغطّيه Plex من محارف، فلا يختفي نصٌّ بلا رسالة.
      final theme = buildTheme();
      for (final style in [
        _resolve(theme.filledButtonTheme.style?.textStyle),
        _resolve(theme.outlinedButtonTheme.style?.textStyle),
        _resolve(theme.navigationBarTheme.labelTextStyle),
      ]) {
        expect(style?.fontFamilyFallback, arabicFallback);
      }
    });
  });

  // ملحوظةٌ تُقرأ قبل أن يُضاف قياسُ عرضٍ هنا:
  //
  // **قياسُ العرض لا يقع في هذا الملفّ.** ليقيسَ شيئاً يحتاج خطّاً محمَّلاً
  // (`flutter test` بلا خطوطٍ يرسم كلَّ محرفٍ مربّعاً بعرضٍ واحدٍ فيستوي
  // العرضان مهما كانت العائلة)، وتحميلُ الخطّ هنا يُعلّق الملفَّ حتى تنفد
  // مهلتُه — جُرّب ثلاثَ مرّات.
  //
  // فالقياسُ في `tool/button_font_proposal_test.dart`: يطبع العرضَ في
  // الحالين (‎١٣٠٫٧‎ ثمّ ‎١٠٧٫٨‎) ويسقط إن لم يفترقا. وهذا الملفُّ يحرس
  // السببَ، وذاك يُظهر الأثر.
}
