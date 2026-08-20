import 'package:flutter/material.dart';
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
}
