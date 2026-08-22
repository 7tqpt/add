// القراءةُ حين تكون القاعدة أقدمَ من التطبيق.
//
// التطبيق يُحدَّث برابط، والقاعدة تُحدَّث بيد صاحبها في محرّر SQL. فبينهما
// نافذةٌ يكون فيها التطبيق أحدثَ — وفيها يجب أن تنقص ميزةٌ لا أن تسقط شاشة.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:aras/src/data/api.dart';

void main() {
  test('عمودٌ منكَر يُعيد القراءةَ بدونه', () async {
    var leanRan = false;
    final value = await whenColumnMissing<String>(
      () => throw const PostgrestException(
        message: 'column service_providers.logo_path does not exist',
        code: '42703',
      ),
      () async {
        leanRan = true;
        return 'الصفّ بلا الشعار';
      },
    );
    expect(leanRan, isTrue);
    expect(value, 'الصفّ بلا الشعار');
  });

  test('ولا شيء يُعاد حين تنجح القراءة الكاملة', () async {
    var leanRan = false;
    final value = await whenColumnMissing<String>(
      () async => 'الصفّ كاملاً',
      () async {
        leanRan = true;
        return 'لا ينبغي أن يقع';
      },
    );
    expect(leanRan, isFalse);
    expect(value, 'الصفّ كاملاً');
  });

  test('وخطأٌ آخر يمرّ كما هو ولا يُبتلع', () async {
    // **وهذا هو الخطر في هذا النمط:** حارسٌ واسع يبتلع «الصلاحية مرفوضة»
    // و«الجدول غير موجود» ويعرض شاشةً ناقصةً بلا خطأٍ في أي سجلّ. فالرمز
    // وحده يُلتقط، وما عداه يصعد.
    expect(
      () => whenColumnMissing<String>(
        () => throw const PostgrestException(message: 'permission denied', code: '42501'),
        () async => 'لا ينبغي أن يقع',
      ),
      throwsA(isA<PostgrestException>()),
    );
  });
}
