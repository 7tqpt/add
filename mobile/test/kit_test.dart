import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:aras/src/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/ui/kit.dart';

void main() {
  group('أيقونة القسم', () {
    test('لكلّ قسمٍ في البذرة أيقونته', () {
      const slugs = [
        'halls', 'catering', 'artists', 'sound', 'photography', 'support',
        'cars', 'attire', 'planners', 'beauty', 'decor', 'printing',
      ];
      for (final slug in slugs) {
        expect(
          categoryIcon(slug),
          isNot(Icons.category_outlined),
          reason: 'القسم «$slug» سقط إلى الأيقونة الافتراضية',
        );
      }
    });

    test('ولا تتكرّر أيقونةٌ بين قسمين', () {
      // أيقونتان متطابقتان تُلغيان فائدة الأيقونة: الصفُّ يُمسح بالعين،
      // فقسمان بالرمز نفسه يُقرآن واحداً.
      const slugs = [
        'halls', 'catering', 'artists', 'sound', 'photography', 'support',
        'cars', 'attire', 'planners', 'beauty', 'decor', 'printing',
      ];
      final icons = slugs.map(categoryIcon).toSet();
      expect(icons.length, slugs.length);
    });

    test('وقسمٌ يُضاف لاحقاً يجد أيقونةً لا فراغاً', () {
      // هذا ما ينكسر بصمت: المالك يضيف قسماً من اللوحة، فتظهر بطاقةٌ
      // نصفُها فارغ ولا خطأ في أي سجلّ.
      expect(categoryIcon('a-brand-new-category'), Icons.category_outlined);
      expect(categoryIcon(''), Icons.category_outlined);
    });
  });

  group('صبغة القسم', () {
    const slugs = [
      'halls', 'catering', 'artists', 'sound', 'photography', 'support',
      'cars', 'attire', 'planners', 'beauty', 'decor', 'printing',
    ];

    test('لكلّ قسمٍ صبغته', () {
      for (final slug in slugs) {
        expect(categoryTone(slug), isNot(AppColors.ink2), reason: 'القسم «$slug» بلا صبغة');
      }
    });

    test('ولا تتكرّر صبغةٌ بين قسمين', () {
      // لونان متطابقان يُلغيان فائدة اللون: الصفُّ يُمسح بالعين، فقسمان
      // بالصبغة نفسها يُقرآن واحداً.
      expect(slugs.map(categoryTone).toSet().length, slugs.length);
    });

    test('والأسطحُ المصبوغة تُقرأ كذلك', () {
      // ثلاثةُ أسطحٍ بلون العلامة يحملها ملفُّ المزوّد وبطاقةُ الخدمة: شارةُ
      // القسم، وقرصُ الحرف، وصفُّ المزوّد. والنصُّ عليها من اللون نفسه —
      // فكلّما ثقُل السطحُ قلّ الفرق بينه وبين حرفه.
      //
      // والقياس من الثابت لا من نسخةٍ منه: `Tint.disc` نفسُها التي يرسم بها
      // الودجت، فرفعُها غداً يُسقط هذا الاختبار لا يمرّ من تحته.
      double lin(double c) =>
          c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
      double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
      const card = Color(0xFFFFFFFE);
      Color over(Color fg, double alpha) => Color.from(
        alpha: 1,
        red: fg.r * alpha + card.r * (1 - alpha),
        green: fg.g * alpha + card.g * (1 - alpha),
        blue: fg.b * alpha + card.b * (1 - alpha),
      );
      double ratio(Color a, Color b) {
        final x = lum(a), y = lum(b);
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
      }

      for (final (name, surface, text) in [
        ('شارة', over(AppColors.accent, Tint.chip), AppColors.accent),
        ('قرص', over(AppColors.accent, Tint.disc), AppColors.accent),
        ('صفّ', over(AppColors.accent, Tint.row), AppColors.ink2),
      ]) {
        final r = ratio(text, surface);
        expect(r, greaterThanOrEqualTo(4.5), reason: '«$name» يعطي ${r.toStringAsFixed(2)}:1');
      }
    });

    test('وكلُّها تُقرأ على أرضية البطاقة', () {
      // القياس هنا لا في ورقةٍ جانبية: لونٌ يُضاف غداً بلا قياسٍ يمرّ صامتاً.
      // العتبة ٤٫٥:١ — والأرضية `#fffffe` وهي أعلى نقطةٍ في تدرّج البطاقة:
      // أبيضُ البطاقة بشفافية ٠٫٩٦ فوق كريم الصفحة.
      double lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
      double lum(Color c) =>
          0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
      const card = Color(0xFFFFFFFE);
      for (final slug in slugs) {
        final a = lum(categoryTone(slug));
        final b = lum(card);
        final ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '«$slug» يعطي ${ratio.toStringAsFixed(2)}:1');
      }
    });
  });
}
