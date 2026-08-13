import 'package:flutter_test/flutter_test.dart';
import 'package:aras/src/core/format.dart';

/// التنسيق هو أكثر ما يظهر للمستخدم وأقلّ ما يُنتبه له: رقمٌ بأرقام هنديّة أو
/// «2 يوم» بدل «يومين» يُقرأ خطأً مطبعياً في المنتج كلّه.
/// الأرقام الهندية ٠١٢٣٤٥٦٧٨٩ — يجب ألّا تظهر في أي مخرَج.
final _indic = RegExp(r'[٠-٩]');

void main() {
  setUpAll(() async => initFormatting());

  // بيانات محلّية الاسم لا تُحمَّل في الاختبار كما تُحمَّل في التطبيق، فمقارنةُ
  // نصٍّ بنصّ قد تنجح هنا وتفشل هناك — وهو ما وقع فعلاً: التاريخ ظهر «١٠ سبتمبر
  // ٢٠٢٦» في التطبيق بينما الاختبار يقرأ لاتينياً. الشرط الصريح يمسك ذلك.
  test('لا أرقام هندية في أي تنسيق', () {
    for (final out in [
      formatMoney(145873),
      formatNumber(2026),
      formatDate('2026-09-10'),
      formatCount(11, dayForms),
      formatTime('20:00'),
    ]) {
      expect(_indic.hasMatch(out), isFalse, reason: 'أرقام هندية في: $out');
    }
  });

  group('formatCount — المطابقة العربية', () {
    test('المفرد والمثنّى يسقط معهما العدد', () {
      expect(formatCount(1, dayForms), 'يوم');
      expect(formatCount(2, dayForms), 'يومين');
      expect(formatCount(1, guestForms), 'ضيف واحد');
      expect(formatCount(2, guestForms), 'ضيفان');
    });

    test('٣–١٠ جمع قلّة', () {
      expect(formatCount(3, dayForms), '3 أيام');
      expect(formatCount(10, dayForms), '10 أيام');
    });

    test('١١ فصاعداً تمييز مفرد منصوب', () {
      expect(formatCount(11, dayForms), '11 يوماً');
      expect(formatCount(120, guestForms), '120 ضيفاً');
    });

    test('الصفر والسالب لا يكسران الصيغة', () {
      expect(formatCount(0, dayForms), '0 يوماً');
      expect(formatCount(-3, dayForms), '3 أيام');
    });
  });

  group('formatMoney', () {
    // ar_EG يُخرج ١٤٥٬٨٧٣، فتختلف الأسعار عن اللوحة. هذا الاختبار يمسك ذلك.
    test('أرقام لاتينية بفاصلة الآلاف ولاحقة الريال', () {
      expect(formatMoney(145873), '145,873 ر.ي');
      expect(formatMoney(0), '0 ر.ي');
    });
  });

  group('formatTime', () {
    test('يحوّل الأربع والعشرين إلى ص/م', () {
      expect(formatTime('20:00'), '8:00 م');
      expect(formatTime('00:30'), '12:30 ص');
      expect(formatTime('12:00'), '12:00 م');
      expect(formatTime('09:05'), '9:05 ص');
    });

    test('الفارغ والمكسور لا يرميان', () {
      expect(formatTime(null), '—');
      expect(formatTime(''), '—');
      expect(formatTime('لاحقاً'), 'لاحقاً');
    });
  });

  group('formatDate', () {
    // بلا initFormatting يرمي LocaleDataException — وهو ما كان يقع فعلاً.
    test('يكتب الشهر بالعربية', () {
      expect(formatDate('2026-08-13'), '13 أغسطس 2026');
    });

    test('النصّ غير التاريخ يُعاد كما هو', () {
      expect(formatDate('—'), '—');
    });
  });

  group('formatRelative', () {
    String at(Duration offset) => DateTime.now().add(offset).toIso8601String();

    test('الماضي بـ«منذ»', () {
      expect(formatRelative(at(const Duration(hours: -3))), 'منذ 3 ساعات');
      expect(formatRelative(at(const Duration(days: -2))), 'منذ يومين');
    });

    // المستقبل كان يُقرأ «الآن» في اللوحة قبل إصلاحه، لأن الفرق سالب فيقع تحت
    // الدقيقة. فموعدُ عرسٍ بعد أسبوع بدا وكأنه وقع للتوّ.
    test('المستقبل بـ«بعد» لا «الآن»', () {
      expect(formatRelative(at(const Duration(days: 7))), 'بعد 7 أيام');
      expect(formatRelative(at(const Duration(hours: 5))), 'بعد 5 ساعات');
    });

    test('اللحظة الحاضرة', () {
      expect(formatRelative(at(Duration.zero)), 'الآن');
    });

    test('ما تجاوز الشهر يصير تاريخاً', () {
      expect(formatRelative('2020-03-01'), '1 مارس 2020');
    });
  });
}
