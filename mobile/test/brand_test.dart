// هويّةُ العلامة: خطٌّ يُشحن فعلاً، وألوانٌ من عائلةٍ واحدة.
//
// **ولماذا اختبارٌ لخطّ:** الخطّ يُذكر في موضعين — `pubspec.yaml` والثيمة —
// وأحدهما يسقط صامتاً. فحذفُ ملفِّ وزنٍ من `assets/fonts` يُسقط البناء
// برسالةٍ صريحة، أمّا حذفُ العائلة من `pubspec.yaml` (أو خطأُ حرفٍ في
// اسمها) فيبني ويعمل: يعود Flutter إلى خطّ النظام بلا كلمةٍ في أي سجل.
//
// وهذا مُجرَّب لا مُقدَّر: حُذفت العائلة من `pubspec.yaml` فمرّت اختبارات
// الشاشات كلُّها خضراء — ولم يلتقطها إلا ما هنا.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';

void main() {
  group('خطّ العلامة', () {
    test('الثيمة تجعله أصلاً لا احتياطاً', () {
      final theme = buildTheme();
      // الأصلُ أوّلاً: لو بقي في `fontFamilyFallback` وحده لسبقه خطُّ الجهاز.
      expect(theme.textTheme.bodyMedium?.fontFamily, brandFont);
      // والاحتياط خلفه لا مكانه: النسخُ يغطّي ما لا يغطّيه Plex.
      expect(arabicFallback, contains('NotoNaskhArabic'));
      expect(arabicFallback.first, brandFont);
    });

    test('وأوزانه الأربعة مذكورةٌ وموجودةٌ على القرص', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $brandFont'));

      for (final weight in [400, 500, 600, 700]) {
        final path = 'assets/fonts/IBMPlexSansArabic-$weight.ttf';
        expect(pubspec, contains(path), reason: 'الوزن $weight غير مذكورٍ في pubspec');
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'الوزن $weight غير موجودٍ على القرص');
        // ملفٌّ فارغٌ أو صفحةُ خطأٍ نُزّلت باسم خطّ: يُذكر ويوجد ولا يعمل.
        expect(file.lengthSync(), greaterThan(50000), reason: 'الوزن $weight أصغر من أن يكون خطّاً');
      }
    });

    test('ورخصتُه مرفقةٌ معه', () {
      // OFL تشترط أن تُرفق مع الخطّ حيثما وُزّع — والتطبيق يوزّعه.
      final licence = File('assets/fonts/IBMPlexSansArabic-OFL.txt');
      expect(licence.existsSync(), isTrue);
      expect(licence.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });
  });

  group('عائلة اللون', () {
    test('الأسطح دافئةٌ لا مزرقّة', () {
      // القياسُ لا النظر: سطحٌ «دافئ» يعني أحمرَه أعلى من أزرقه. وهذا ما
      // ينقلب بسطرٍ واحدٍ يُلصق من اللوحة الزرقاء فلا يلحظه أحد.
      for (final (name, c) in [
        ('page', AppColors.page),
        ('surface2', AppColors.surface2),
        ('hairline', AppColors.hairline),
        ('ink', AppColors.ink),
        ('ink2', AppColors.ink2),
        ('muted', AppColors.muted),
        ('accent', AppColors.accent),
      ]) {
        expect(c.r, greaterThan(c.b), reason: '«$name» أزرقُه أعلى من أحمره');
      }
    });

    test('والنبيذيّ نبيذيٌّ لا أحمرَ صريح', () {
      // أحمرُ الخطأ وأحمرُ العلامة يجب أن يفترقا: لو تقاربا لقُرئ زرُّ
      // «احجز الآن» تحذيراً.
      final brand = HSLColor.fromColor(AppColors.accent);
      final danger = HSLColor.fromColor(AppColors.critical);
      expect(brand.lightness, lessThan(0.35));
      expect((brand.hue - danger.hue).abs(), greaterThan(20));
    });
  });
}
