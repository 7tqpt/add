// قراءةُ الموقع من رابطٍ مُلصَق.
//
// **وهذه دالّةٌ نقيّةٌ تُقاس بلا شاشةٍ ولا شبكة** — فتُكتب بـ`test` لا
// `testWidgets`، والحالاتُ فيها رخيصةٌ فتُغطّى كلُّها.
//
// وما يُقاس هنا ليس «أتقرأ رقمين؟» بل **أتقرأ الرقمين الصحيحين**: رابطُ
// خرائط Google يحمل في جوفه أرقاماً كثيرة — درجةَ التقريب، ومعرّفاتٍ طويلة،
// وأحياناً نقطتين — ومن أخذ أوّلَ ما يشبه إحداثيّةً وقع على غير ما ينظر إليه
// صاحبُ الرابط.
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/geo.dart';

void main() {
  const sanaa = GeoPoint(15.354722, 44.206667);

  group('قراءةُ النقطة من رابط', () {
    test('رابطُ خرائط بصيغة @', () {
      expect(
        parseGeoLink('https://www.google.com/maps/@15.354722,44.206667,17z'),
        sanaa,
      );
    });

    test('ورابطٌ بصيغة q=', () {
      expect(
        parseGeoLink('https://maps.google.com/?q=15.354722,44.206667'),
        sanaa,
      );
    });

    test('**ورابطُ مكانٍ يُقرأ من دبّوسه لا من كاميرته**', () {
      // رابطُ «مكان» يحمل نقطتين: `@` مركزُ الشاشة حين نُسخ الرابط — وقد
      // حرّك صاحبُه الخريطة قبل النسخ فبعُد مئات الأمتار — و`!3d!4d` دبّوسُ
      // المكان نفسه. والدبّوسُ هو الجواب.
      //
      // وأوّلُ ما كُتب هنا كان يُرجع الكاميرا. قِيس فظهر.
      expect(
        parseGeoLink(
          'https://www.google.com/maps/place/قاعة+التاج/@15.300000,44.100000,17z'
          '/data=!3m1!4b1!4m6!3m5!1s0x1605!8m2!3d15.354722!4d44.206667',
        ),
        sanaa,
        reason: 'أُخذ مركزُ الكاميرا بدل دبّوس المكان',
      );
    });

    test('**ورابطُ مكانٍ لا `@` فيه أصلاً يُقرأ**', () {
      // صيغةٌ تخرج من زرّ «مشاركة» في التطبيق. وأوّلُ ما كُتب هنا كان يردّها
      // `null` — أي يقول لصاحب الرابط الصحيح «لم أفهم».
      expect(
        parseGeoLink(
          'https://www.google.com/maps/place/X/'
          'data=!4m2!3m1!1s0x1605:0x9!8m2!3d15.354722!4d44.206667',
        ),
        sanaa,
      );
    });

    test('ورابطٌ بـ@ وحده يُقرأ منه', () {
      expect(
        parseGeoLink('https://www.google.com/maps/@15.354722,44.206667,17z'),
        sanaa,
      );
    });

    test('وصيغة geo:', () {
      expect(parseGeoLink('geo:15.354722,44.206667'), sanaa);
    });

    test('ولصقٌ مجرّدٌ برقمين', () {
      expect(parseGeoLink('15.354722, 44.206667'), sanaa);
      expect(parseGeoLink('15.354722،44.206667'), sanaa,
          reason: 'الفاصلة العربية لا تُقرأ');
    });

    test('والمسافاتُ حول النصّ لا تمنع', () {
      expect(parseGeoLink('   geo:15.354722,44.206667  '), sanaa);
    });

    test('وإحداثيّةٌ سالبةٌ تُقرأ', () {
      // لا عرسَ في نصف الكرة الجنوبي غالباً، لكنّ الإشارة تُقرأ أو لا تُقرأ.
      expect(parseGeoLink('geo:-15.5,-44.2'), const GeoPoint(-15.5, -44.2));
    });
  });

  group('وما لا يُقرأ يُردّ صراحةً', () {
    test('نصٌّ ليس فيه موقع', () {
      expect(parseGeoLink('حي السنينة بجانب مسجد النور'), isNull);
    });

    test('وفراغ', () {
      expect(parseGeoLink('   '), isNull);
    });

    test('**والرابطُ المختصر يُردّ ولا يُخمَّن**', () {
      // لا رقمَ فيه أصلاً. ولو أُرجعت منه نقطةٌ لكانت اختراعاً.
      expect(parseGeoLink('https://maps.app.goo.gl/AbCdEfGh1'), isNull);
    });

    test('وخارج المدى يُردّ', () {
      expect(parseGeoLink('geo:91.5,44.2'), isNull);
      expect(parseGeoLink('geo:15.5,181.2'), isNull);
    });

    test('**وصفرٌ صفرٌ ليست نقطة**', () {
      // «جزيرة نُل» في خليج غينيا — وما يصل إليها في تطبيقٍ يمنيّ إنّما هو
      // حقلٌ لم يُملأ فقُرئ صفراً.
      expect(parseGeoLink('geo:0.0,0.0'), isNull);
      expect(const GeoPoint(0, 0).isValid, isFalse);
    });

    test('وأرقامٌ صحيحةٌ بلا كسرٍ لا تُقرأ لصقاً مجرّداً', () {
      // `300, 500` عددُ ضيوفٍ ومبلغٌ لا موقع. واشتراطُ الكسر يفصل بينهما.
      expect(parseGeoLink('300, 500'), isNull);
    });
  });

  group('نقطةُ البدء', () {
    test('نقطتُه المحفوظة أوّلاً', () {
      expect(startingPoint(saved: sanaa, governorate: 'عدن'), sanaa);
    });

    test('فمركزُ محافظته', () {
      final aden = startingPoint(governorate: 'عدن');
      expect(aden.lat, closeTo(12.78, 0.1));
      expect(aden.lng, closeTo(45.02, 0.1));
    });

    test('**ولا تُفتح الخريطةُ في المحيط لمن لا محافظةَ له**', () {
      final fallback = startingPoint(governorate: 'محافظةٌ لا وجود لها');
      expect(fallback.isValid, isTrue);
      expect(fallback.lat, closeTo(15.37, 0.5), reason: 'ليست صنعاء');
    });

    test('وكلُّ مركزٍ في الجدول نقطةٌ ممكنة', () {
      // **جدولٌ مكتوبٌ باليد يُخطأ فيه:** خانةٌ ناقصةٌ تضع «تعز» في المحيط
      // الهندي، ولا شيء في التطبيق يقول ذلك — تُفتح الخريطةُ على ماء.
      for (final entry in governorateCenters.entries) {
        expect(entry.value.isValid, isTrue, reason: entry.key);
        // واليمن بين ١٢ و١٩ شمالاً، و٤٢ و٥٤ شرقاً.
        expect(entry.value.lat, inInclusiveRange(12, 19), reason: entry.key);
        expect(entry.value.lng, inInclusiveRange(42, 54), reason: entry.key);
      }
    });
  });

  test('ورابطُ الفتح يحمل النقطة بستّ خانات', () {
    expect(mapsUrl(sanaa), contains('15.354722,44.206667'));
    expect(mapsUrl(sanaa), startsWith('https://'),
        reason: 'geo: لا يُفتح على جهازٍ بلا تطبيق خرائط');
  });

  // ==========================================================================
  //  المسافة — نسخةُ `distance_km` في القاعدة
  // ==========================================================================
  //
  // **ولا يُقاس «أيُعيد رقماً؟» بل أيعيد الرقمَ الصحيح.** والمسافاتُ بين
  // المدن اليمنيّة معروفةٌ جغرافيّاً، فتُقاس عليها: صنعاء وعدن نحو ٣٠٠ كم في
  // خطّ الطائر — والطريقُ بينهما أطولُ بكثير، وهذا ما يخلط.
  //
  // ويجب أن تُطابق ما في الخادم: هو يرتّب بها والتطبيقُ يعرض بها الرقم، فلو
  // اختلفا لَقال الترتيبُ شيئاً وقالت البطاقةُ غيره.
  group('المسافة', () {
    const aden = GeoPoint(12.788440, 45.036560);
    const taiz = GeoPoint(13.578300, 44.017700);

    test('صنعاء وعدن نحو ٣٠٠ كم', () {
      final d = distanceKm(sanaa, aden);
      expect(d, greaterThan(290));
      expect(d, lessThan(310));
    });

    test('وعدن وتعزّ نحو ١٤٠ كم', () {
      final d = distanceKm(aden, taiz);
      expect(d, greaterThan(130));
      expect(d, lessThan(150));
    });

    test('والنقطةُ من نفسها صفر', () {
      expect(distanceKm(sanaa, sanaa), closeTo(0, 0.0001));
    });

    test('ولا تتغيّر بانعكاس الطرفين', () {
      expect(distanceKm(sanaa, aden), closeTo(distanceKm(aden, sanaa), 0.0001));
    });

    test('وتعزُّ أقربُ إلى صنعاء من عدن', () {
      expect(distanceKm(sanaa, taiz), lessThan(distanceKm(sanaa, aden)));
    });
  });

  // ==========================================================================
  //  نصُّ المسافة
  // ==========================================================================
  //
  // **ودون الكيلومتر تُقال بالأمتار:** «٠٫٤ كم» تُقرأ بجهد و«٤٠٠ م» بنظرة.
  group('نصُّ المسافة', () {
    test('دون الكيلومتر بالأمتار', () {
      expect(distanceLabel(0.4), '400 م');
      expect(distanceLabel(0.75), '750 م');
    });

    test('ودونَ العشرة بخانةٍ واحدة', () => expect(distanceLabel(4.26), '4.3 كم'));

    test('وفوقها بلا كسور', () {
      // ومن يختار بين قاعتين على بُعد ١٢ و١٣ كم لا يعنيه المئةُ متر.
      expect(distanceLabel(12.4), '12 كم');
      expect(distanceLabel(299.06), '299 كم');
    });
  });

  // ==========================================================================
  //  الترتيبُ بالقرب — وضعُ العرض
  // ==========================================================================
  group('الترتيبُ بالقرب', () {
    const near = GeoPoint(15.3350, 44.1780); // السنينة
    const mid = GeoPoint(15.3690, 44.2600); // سعوان
    const far = GeoPoint(12.7960, 45.0230); // عدن

    test('**الأقربُ أوّلاً**', () {
      final list = [far, mid, near];
      sortByDistance(list, sanaa, (p) => p);
      expect(list, [near, mid, far]);
    });

    test('**ومن لا نقطةَ له آخراً لا خارجَ القائمة**', () {
      // وإخفاؤه عقوبةٌ للعميل قبل المزوّد: هو موجودٌ ويعمل.
      final list = <GeoPoint?>[null, far, near];
      sortByDistance(list, sanaa, (p) => p);
      expect(list.length, 3, reason: 'سقط أحدُهم من القائمة');
      expect(list.first, near);
      expect(list.last, isNull);
    });

    test('ومن لا نقطةَ لهم جميعاً يبقون كما هم', () {
      final list = <GeoPoint?>[null, null];
      sortByDistance(list, sanaa, (p) => p);
      expect(list.length, 2);
    });
  });
}
