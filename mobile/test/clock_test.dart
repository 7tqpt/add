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
    test('رمزُ المستقبل يقول: اضبط ساعة الجوال', () {
      final hint = identityHint(jwtIssuedAtFuture, const Duration(minutes: 7));
      expect(hint, contains('الساعة'));
      expect(hint, contains('التلقائي'));
      // والرقم المقيس فيه.
      expect(hint, contains('تسبق'));
      // ولا يُرسَل صاحبُه إلى ملفات SQL.
      expect(hint, isNot(contains('supabase/')));
    });

    test('والجدولُ الغائب يقول: شغّل الملفات', () {
      expect(identityHint('42P01'), contains('supabase/'));
      expect(identityHint('42P01'), isNot(contains('الساعة')));
    });

    test('والعمودُ الغائب يقول: قاعدتك أقدم', () {
      expect(identityHint('42703'), contains('أقدم'));
    });

    test('وما لا رمزَ له يقول شيئاً عامّاً لا شيئاً خاطئاً', () {
      expect(identityHint(null), isNotEmpty);
      expect(identityHint(null), isNot(contains('الساعة')));
    });
  });
}
