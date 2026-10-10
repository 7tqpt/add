// فرقُ الساعة: كيف يُقال لصاحب الجهاز، وماذا يُقال لكل رمز عطب.
//
// وأهمّ ما هنا أن **التشخيص يتبع الرمز**: كانت الشاشة تقول لكل عطبٍ «الغالب
// أن ملفات المخطّط لم تُطبَّق»، فمن وقع عليه فرقُ ساعةٍ بحث في مجلّد سليم.
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/data/supabase.dart';
import 'package:aras/src/screens/root.dart';

void main() {
  group('وصفُ الفرق', () {
    test('الفرق الصغير لا يُذكر', () {
      // ثوانٍ معدودة تمرّ وحدها، وذكرُها يُقلق بلا سبب.
      expect(clockSkewLabel(const Duration(seconds: 12)), isNull);
      expect(clockSkewLabel(const Duration(seconds: -12)), isNull);
      expect(clockSkewLabel(null), isNull);
    });

    test('والجهازُ المتقدّم يُقال إنه يسبق', () {
      final label = clockSkewLabel(const Duration(minutes: 7));
      expect(label, contains('تسبق'));
      // والأرقام لاتينية هنا كما في بقية التطبيق.
      expect(label, contains('7 دقائق'));
    });

    test('والمتأخّرُ يُقال إنه متأخّر', () {
      final label = clockSkewLabel(const Duration(minutes: -7));
      expect(label, contains('متأخّرة'));
    });

    test('والساعاتُ تُصرَّف ساعاتٍ لا دقائق', () {
      expect(clockSkewLabel(const Duration(hours: 3)), contains('ساعات'));
    });
  });

  group('التشخيص', () {
    test('ساعةُ الجوال المتقدّمة: الرقمُ وما يُفعل', () {
      final hint = identityHint(jwtIssuedAtFuture, const Duration(minutes: 7));
      expect(hint, contains('التلقائي'));
      // والرقم المقيس فيه.
      expect(hint, contains('تسبق'));
      expect(identityTitle(jwtIssuedAtFuture, const Duration(minutes: 7)),
          'ساعة جوالك غير مضبوطة');
    });

    test('وبلا فرقٍ مقيسٍ لا يُتّهم الجوال — العطبُ من الخادم', () {
      expect(identityHint(jwtIssuedAtFuture), isNot(contains('التلقائي')));
      expect(identityTitle(jwtIssuedAtFuture), 'تعذّر فتح حسابك الآن');
    });

    test('**ولا نصَّ مطوّرٍ لأيّ رمز** — اختار صاحبُ المنصّة (ب)', () {
      // كانت «الجدولُ الغائب يقول: شغّل الملفات» — ووقعت على عميل.
      expect(identityHint('42P01'), isNot(contains('supabase/')));
      expect(identityHint('42703'), isNot(contains('supabase/')));
      expect(identityHint(null), isNotEmpty);
      expect(identityHint(null), isNot(contains('ساعة')));
    });
  });
}
