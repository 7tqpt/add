// رقمُ الجوال: ما يُقبل وما يُردّ.
//
// **وأصلُ هذا رقمٌ سُجّل في ملفّ صاحب المنصّة:** `+96657671431` — مفتاحُ
// السعوديّة وبعده ثمانِ خاناتٍ لا تسع. فلم يكن رقماً على أيّ شبكة، ولم يظهر
// ذلك حتى طُلب رمزُ تحقّقٍ فلم يجد إلى أين يذهب. وقبله كان الحقلُ يقبل أيَّ
// شيءٍ غيرِ فارغ.
//
// **والرقمُ هو ما يُتواصل به في كلّ حجز** — فرقمٌ ناقصٌ بخانةٍ يعني عرساً
// يُتّصل فيه بصاحبه فلا يُوجد.
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/phone.dart';

void main() {
  group('ما يُردّ', () {
    test('**والرقمُ الذي أوقعنا هنا يُردّ**', () {
      // ثمانِ خاناتٍ بعد 966، والصوابُ تسعٌ.
      expect(normalisePhone('+96657671431'), isNull);
    });

    test('ويمنيٌّ ناقصُ خانة', () {
      expect(normalisePhone('+96777123456'), isNull);
      expect(normalisePhone('77123456'), isNull);
    });

    test('ويمنيٌّ زائدُ خانة', () {
      expect(normalisePhone('+9677712345678'), isNull);
    });

    test('**وأرضيٌّ يمنيٌّ لا يصله واتساب**', () {
      // تسعُ خاناتٍ لكنّها تبدأ بـ1 — هاتفُ منزلٍ لا جوال.
      expect(normalisePhone('+967112345678'), isNull);
      expect(normalisePhone('+967123456789'), isNull);
    });

    test('وسعوديٌّ لا يبدأ بـ5', () {
      expect(normalisePhone('+966112345678'), isNull);
    });

    test('وفارغٌ أو حروف', () {
      expect(normalisePhone(''), isNull);
      expect(normalisePhone('   '), isNull);
      expect(normalisePhone('رقمي'), isNull);
      expect(normalisePhone('+'), isNull);
    });

    test('ومفتاحٌ مجهولٌ برقمٍ قصيرٍ ظاهرِ النقص', () {
      expect(normalisePhone('+20100'), isNull);
    });
  });

  group('ما يُقبل ويُطهَّر', () {
    test('**واليمنُ هو الافتراضُ لمن كتب رقمَه محلّيّاً**', () {
      expect(normalisePhone('771234567'), '+967771234567');
      expect(normalisePhone('0771234567'), '+967771234567');
    });

    test('ومكتوبٌ بفراغاتٍ وشُرَطٍ وأقواس', () {
      expect(normalisePhone('+967 771 234 567'), '+967771234567');
      expect(normalisePhone('(0771) 234-567'), '+967771234567');
    });

    test('**والأرقامُ العربيّةُ تُبدَّل**', () {
      // من كتب بلوحةٍ عربيّةٍ أخرج «٧٧١…» — ولا فرقَ عنده، وهي عند الشبكة
      // حروفٌ لا أرقام.
      expect(normalisePhone('٠٧٧١٢٣٤٥٦٧'), '+967771234567');
      expect(normalisePhone('+٩٦٧٧٧١٢٣٤٥٦٧'), '+967771234567');
    });

    test('و`00` تقوم مقام `+`', () {
      expect(normalisePhone('00967771234567'), '+967771234567');
    });

    test('ومفتاحٌ بلا `+`', () {
      expect(normalisePhone('967771234567'), '+967771234567');
      expect(normalisePhone('966512345678'), '+966512345678');
    });

    test('وسعوديٌّ صحيح', () {
      expect(normalisePhone('+966512345678'), '+966512345678');
    });

    test('**ومفتاحٌ لا نعرفه لا يُردّ لأنّنا لم نكتب بلدَه**', () {
      // من يسجّل من مصرَ أو الأردنّ أو الإمارات لا يُحبس خارج المنصّة.
      expect(normalisePhone('+201012345678'), '+201012345678');
      expect(normalisePhone('+971501234567'), '+971501234567');
    });

    test('وما طُهِّر مرّةً يبقى كما هو إن طُهِّر ثانية', () {
      // **وهذا يُقاس لأنّ الرقمَ يمرّ بالمُطهِّر في الشاشة ثمّ في الخادم.**
      final once = normalisePhone('0771234567')!;
      expect(normalisePhone(once), once);
    });
  });

  test('وسؤالُ الصلاحيّة يوافق التطهير', () {
    expect(isValidPhone('0771234567'), isTrue);
    expect(isValidPhone('+96657671431'), isFalse);
  });
}
