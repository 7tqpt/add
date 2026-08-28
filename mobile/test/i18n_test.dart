// اللغة: التبديلُ يعمل، والترجمةُ الناقصةُ لا تكسر شيئاً.
//
// **وأصدقُ ما هنا هو اختبارُ التغطية**: يطبع كم نصّاً تُرجم من كم، ويمنع أن
// تنقص النسبة. فالجدولُ ينمو دفعةً بعد دفعة، والرقمُ يقول أين نحن — لا
// «أُنجزت الترجمة» ولا «لم تُنجز».
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/strings_en.dart';

void main() {
  tearDown(() => appLocale.value = AppLocale.ar);

  // ==========================================================================
  //  الترجمة
  // ==========================================================================

  group('tr', () {
    test('في العربيّة يعيد النصَّ كما هو', () {
      appLocale.value = AppLocale.ar;
      expect(tr('حجوزاتي'), 'حجوزاتي');
    });

    test('**وفي الإنجليزيّة يترجم**', () {
      appLocale.value = AppLocale.en;
      expect(tr('حجوزاتي'), 'My bookings');
    });

    test('**وما لا ترجمةَ له يُعرض بالعربيّة لا برمزٍ ولا فراغ**', () {
      // وهذا هو القرار: أسوأُ ما يقع أن يرى الإنجليزيُّ كلمةً عربيّة، لا أن
      // يرى `booking.confrm.title` أو سطراً فارغاً.
      appLocale.value = AppLocale.en;
      const missing = 'نصٌّ لم يُترجم بعدُ قطعاً';
      expect(tr(missing), missing);
    });

    test('ونصٌّ فارغٌ لا يكسر', () {
      appLocale.value = AppLocale.en;
      expect(tr(''), '');
    });
  });

  group('trf', () {
    test('**النائبُ المرقَّم يُبدَّل**', () {
      appLocale.value = AppLocale.ar;
      expect(trf('أُزيلت {0} من المفضّلة', ['قاعة التاج']),
          'أُزيلت قاعة التاج من المفضّلة');
    });

    test('ونائبان بترتيبهما', () {
      expect(trf('{0} من {1}', ['٣', '١٢']), '٣ من ١٢');
    });

    test('ونائبٌ لم يُعطَ يبقى كما هو ولا يرمي', () {
      expect(trf('{0} و{1}', ['أ']), 'أ و{1}');
    });
  });

  // ==========================================================================
  //  الاتّجاه واللغة
  // ==========================================================================

  test('**الاتّجاه يتبع اللغة**', () {
    expect(localeOf(AppLocale.ar).languageCode, 'ar');
    expect(localeOf(AppLocale.en).languageCode, 'en');
  });

  test('واسمُ اللغة بلغتها هي', () {
    // من يبحث عن الإنجليزيّة في شاشةٍ عربيّة يبحث عن كلمة `English`.
    expect(localeName(AppLocale.en), 'English');
    expect(localeName(AppLocale.ar), 'العربية');
  });

  // ==========================================================================
  //  **سلامةُ الجدول**
  // ==========================================================================

  group('جدولُ الإنجليزيّة', () {
    test('**لا مفتاحَ فيه يحمل قيمةً تُدرَج**', () {
      // نصٌّ فيه `$` لا يصلح مفتاحاً: قيمتُه تختلف في كلّ نداء، فلا يُطابَق
      // أبداً. وما يحمل قيمةً يُبنى بـ`trf` بنائبٍ مرقَّم.
      final bad = englishStrings.keys.where((k) => k.contains(r'$')).toList();
      expect(bad, isEmpty, reason: 'مفاتيحُ لا تُطابَق أبداً: $bad');
    });

    test('ولا قيمةَ فارغة', () {
      final empty = englishStrings.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(empty, isEmpty, reason: 'ترجماتٌ فارغة: $empty');
    });

    test('**ولا قيمةَ عربيّة** — تلك ترجمةٌ لم تقع', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final untranslated = englishStrings.entries
          .where((e) => arabic.hasMatch(e.value))
          .map((e) => e.key)
          .toList();
      expect(untranslated, isEmpty,
          reason: 'قيمٌ بقيت عربيّةً: $untranslated');
    });
  });

  // ==========================================================================
  //  **التغطية — الرقمُ الذي يقول أين نحن**
  // ==========================================================================

  test('تغطيةُ الترجمة لا تنقص', () {
    // يُقرأ المصدرُ نفسُه ويُعدّ ما لُفّ بـ`tr(` وما لم يُلفّ بعد. ولا
    // يُشترط الكمال — يُشترط ألّا نتراجع.
    final arabic = RegExp(r'[؀-ۿ]');
    final dir = Directory('lib/src');
    var wrapped = 0;
    var loose = 0;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      // بيانات العرض محتوىً لا واجهة، وجداولُ اللغة نفسُها ليست نصَّ شاشة.
      if (file.path.contains('demo.dart') ||
          file.path.contains('strings_en.dart') ||
          file.path.contains('i18n.dart')) {
        continue;
      }
      for (final line in file.readAsLinesSync()) {
        final st = line.trimLeft();
        if (st.startsWith('//') || st.startsWith('*')) continue;
        for (final m in RegExp(r"'((?:[^'\\]|\\.)*)'").allMatches(line)) {
          final lit = m.group(1)!;
          if (!arabic.hasMatch(lit)) continue;
          if (line.contains("tr('$lit')") || line.contains("trf('$lit'")) {
            wrapped++;
          } else {
            loose++;
          }
        }
      }
    }
    final total = wrapped + loose;
    final pct = total == 0 ? 0 : (wrapped * 100 / total).round();
    // ignore: avoid_print
    print('تغطيةُ الترجمة: $wrapped من $total نصّاً ($pct٪) — و$loose باقية.');

    // **حدٌّ يمنع التراجع لا يدّعي الكمال.** يُرفع مع كلّ دفعة.
    expect(wrapped, greaterThanOrEqualTo(45),
        reason: 'تراجعت التغطية عمّا كانت');
  });
}
