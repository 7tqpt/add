// اللغة: التبديلُ يعمل، والترجمةُ تصل الشاشةَ فعلاً.
//
// ── ما كان هنا وما أُضيف ────────────────────────────────────────────────────
//
// كان هذا الملفّ يقيس **الآلة**: `tr` تترجم، و`trf` تُبدّل النائب، والجدولُ
// سليمٌ لا مفتاحَ فيه يحمل قيمةً تُدرَج ولا قيمةَ فيه بقيت عربيّة. وكلُّ
// ذلك باقٍ أدناه، وهو حقّ.
//
// **وما لم يكن يقيسه: أن تُنادى.** فكان في `strings_en.dart` مئتان وخمسةٌ
// وسبعون مدخلاً، وفي `lib/src` **خمسةُ ملفّاتٍ** تنادي `tr()` من نيّفٍ
// وخمسين — ومنها واحدٌ ينادي بنصوصٍ لا مدخلَ لها أصلاً. أي أنّ الترجمةَ
// كانت موجودةً ولا تصل الشاشة: من بدّل اللغةَ إلى الإنجليزيّة رأى عربيّةً
// كما هي، والحزمةُ خضراء.
//
// ── ولماذا يُقرأ المصدرُ لا الشاشةُ المرسومة ────────────────────────────────
//
// الأقربُ إلى عادة هذا المشروع أن تُبنى الشاشةُ بالإنجليزيّة ويُقرأ ما رُسم
// فيها. وهو هنا **يقيس الشيءَ الخطأ**: أكثرُ ما في الشاشة من عربيّةٍ ليس
// واجهةً بل **بيانات** — «قاعة التاج الملكي» و«أمانة العاصمة» وأسماءُ
// الخدمات. وهذه تأتي من القاعدة ولا تُترجَم أصلاً: من فتح التطبيقَ
// بالإنجليزيّة في اليمن يجب أن يرى اسمَ القاعة كما كتبه صاحبُها.
//
// فالمقياسُ الصحيح: **كلُّ نصٍّ عربيٍّ مكتوبٍ في الشيفرة** يجب أن يمرّ
// بـ`tr()`. وما جاء من القاعدة لا يمرّ بها ولا يُسأل عنه.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/strings_en.dart';


/// الملفّاتُ التي تمّت ترجمتُها — والحارسُ يلزمها وحدَها.
///
/// **وقائمةٌ تكبر لا رقمٌ ينزل.** البديلُ المعتاد أن يُحدّ العددُ الكلّيُّ
/// لِما لم يُترجَم ثمّ يُنقص («لا تزد على ٤٠٠») — وهو حدٌّ يمرّ منه نصٌّ
/// جديدٌ غيرُ مترجَمٍ ما دام غيرُه قد تُرجم في اليوم نفسِه. وهذه القائمةُ
/// تقول: **هذه الملفّاتُ تمّت، ولا تنقص.**
const _translated = <String>[
  'lib/src/ui/kit.dart',
  'lib/src/ui/share_button.dart',
  'lib/src/core/app_lock.dart',
  'lib/src/screens/customer_shell.dart',
  'lib/src/screens/home.dart',
  'lib/src/screens/lock.dart',
  'lib/src/screens/update_prompt.dart',
];

// ── مستخرِجُ النصوص ─────────────────────────────────────────────────────────
//
// **ولا يُقرأ الملفُّ بتعبيرٍ نمطيّ.** التعليقاتُ في هذا المشروع عربيّةٌ
// كلُّها، فتعبيرٌ يبحث عن العربيّة يجد التعليقاتِ قبل النصوص. وقصُّ ما بعد
// `//` يقطع `'https://…'` في منتصفه.
//
// فيُمشى الملفُّ حرفاً حرفاً بحالةٍ: داخل نصّ، داخل تعليق، أو خارجهما.

class _Literal {
  _Literal(this.text, this.before, this.line);

  /// ما بين علامتَي الاقتباس.
  final String text;

  /// آخرُ ما قبل علامة الفتح — تُعرف منه المناداة.
  final String before;

  final int line;
}

List<_Literal> _literals(String source) {
  final out = <_Literal>[];
  var i = 0;
  var line = 1;

  while (i < source.length) {
    final c = source[i];

    // تعليقُ سطر
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // تعليقٌ ممتدّ
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') line++;
        i++;
      }
      i += 2;
      continue;
    }

    if (c == "'" || c == '"') {
      final start = i;
      final startLine = line;
      final buffer = StringBuffer();

      // **والمتلاصقاتُ نصٌّ واحد.** Dart تلصق `'أ' 'ب'` قبل أن تُمرَّر، وهي
      // كتابةٌ شائعةٌ هنا لتقصير السطور. فلو قُرئت نصّين لَظهر الثاني «غيرَ
      // منادىً» وهو داخل `tr` نفسِها، ولَطُلبت للأوّل ترجمةٌ بنصفِ جملة.
      // — وقد أخرج الحارسُ ذلك فعلاً في أوّل تشغيل، وكان عيبَ الحارس.
      while (i < source.length && (source[i] == "'" || source[i] == '"')) {
        final q = source[i];
        final triple = i + 2 < source.length && source[i + 1] == q && source[i + 2] == q;

        if (triple) {
          i += 3;
          while (i + 2 < source.length &&
              !(source[i] == q && source[i + 1] == q && source[i + 2] == q)) {
            if (source[i] == '\n') line++;
            buffer.write(source[i]);
            i++;
          }
          i += 3;
        } else {
          i++;
          while (i < source.length && source[i] != q) {
            // والهروبُ يُتخطّى بحرفه: `'it\'s'` ليست نصّين.
            if (source[i] == r'\' && i + 1 < source.length) {
              buffer.write(source[i + 1]);
              i += 2;
              continue;
            }
            if (source[i] == '\n') line++;
            buffer.write(source[i]);
            i++;
          }
          i++;
        }

        // تُتخطّى الفراغاتُ وحدَها بحثاً عن لاصقٍ — ولا تعليقات: تعليقٌ بين
        // جزأين يفصل الجملةَ في القراءة ويجمعها في التنفيذ، ولا يُكتب.
        var j = i;
        while (j < source.length && (source[j] == ' ' || source[j] == '\n' || source[j] == '\r' || source[j] == '\t')) {
          j++;
        }
        if (j < source.length && (source[j] == "'" || source[j] == '"')) {
          while (i < j) {
            if (source[i] == '\n') line++;
            i++;
          }
          continue;
        }
        break;
      }

      final from = start - 8 < 0 ? 0 : start - 8;
      out.add(_Literal(buffer.toString(), source.substring(from, start), startLine));
      continue;
    }

    if (c == '\n') line++;
    i++;
  }

  return out;
}

final _arabic = RegExp(r'[؀-ۿ]');

bool _hasArabic(String s) => _arabic.hasMatch(s);

/// هل النصُّ منادىً بالترجمة — `tr('…')` أو `trf('…', …)`.
bool _wrapped(_Literal lit) {
  final before = lit.before.replaceAll(RegExp(r'\s'), '');
  return before.endsWith('tr(') || before.endsWith('trf(');
}

String _read(String path) => File(path).readAsStringSync();

/// نصٌّ عربيٌّ ليس واجهةً — يُعفى بعلامةٍ في سطره أو في السطر الذي قبله.
///
/// **والاستثناءُ يُكتب في موضعه لا في قائمةٍ بعيدة.** قائمةٌ في أعلى ملفّ
/// الاختبار تُملأ مرّةً ثمّ لا يعود أحدٌ يسأل عمّا فيها. وعلامةٌ إلى جانب
/// السطر يقرؤها من يمرّ به، ويرى معها **سببَها** — فإن كان السببُ باطلاً
/// ظهر بطلانُه في مكانه.
///
/// وأصلُ هذا حالةٌ واحدةٌ صحيحة: `' و'` في `splitCategoryLabel` ليست نصّاً
/// يُعرض بل **أداةَ تقسيمٍ** تُشقّ بها أسماءُ الأقسام الآتيةُ من القاعدة —
/// وهي عربيّةٌ أبداً مهما كانت لغةُ الشاشة. وترجمتُها تكسر التقسيم.
///
/// **ولا يُكتفى بأن تُكتب في موضعها.** الحارسُ لا يقرأ السببَ ولا يستطيع،
/// فعلامةٌ بلا عدٍّ بابٌ يُهرَّب منه كلُّ نصّ: يُلصق `i18n-ignore` فوق ما
/// يُستثقل لفُّه وتبقى الحزمةُ خضراء. **فتُعدّ.** وزيادةُ واحدةٍ تُسقط
/// الحزمةَ حتى يُرفع السقفُ بيدٍ — وهو فعلٌ ظاهرٌ يُراجَع، لا سهوٌ يمرّ.
///
/// (وهذا جاء من ضابطٍ سالبٍ لم يسقط: وُضعت العلامةُ على «المزيد» — وهو
/// نصُّ واجهةٍ محض — فبقيت الحزمةُ خضراء.)
bool _excused(List<String> lines, _Literal lit) {
  bool marked(int n) =>
      n >= 1 && n <= lines.length && lines[n - 1].contains('i18n-ignore');
  return marked(lit.line) || marked(lit.line - 1);
}

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
  //  ١) الملفّاتُ المترجَمة تبقى مترجَمة
  // ==========================================================================
  group('ما تُرجم لا ينكص', () {
    for (final path in _translated) {
      test(path, () {
        expect(File(path).existsSync(), isTrue, reason: 'الملفُّ في القائمة ولا وجودَ له');

        final source = _read(path);
        final lines = source.split('\n');

        final bare = _literals(source)
            .where((l) => _hasArabic(l.text) && !_wrapped(l) && !_excused(lines, l))
            .toList();

        expect(
          bare.map((l) => '${l.line}: ${l.text}').toList(),
          isEmpty,
          reason: 'نصوصٌ عربيّةٌ لا تمرّ بـtr() في ملفٍّ أُعلن أنّه مترجَم',
        );
      });
    }
  });

  // ==========================================================================
  //  ٢) والإعفاءاتُ معدودة
  // ==========================================================================
  test('ولا تزداد الإعفاءات', () {
    final excused = <String>[];

    for (final path in _translated) {
      final source = _read(path);
      final lines = source.split('\n');
      for (final lit in _literals(source)) {
        if (_hasArabic(lit.text) && !_wrapped(lit) && _excused(lines, lit)) {
          excused.add('$path:${lit.line} — ${lit.text}');
        }
      }
    }

    expect(
      excused.length,
      lessThanOrEqualTo(exemptionsCeiling),
      reason: 'إعفاءٌ جديدٌ من الترجمة — إن كان بحقٍّ فارفع السقفَ بيدك:\n'
          '${excused.join('\n')}',
    );
  });

  // ==========================================================================
  //  ٣) وما نودي به موجودٌ في المعجم
  // ==========================================================================
  //
  //  **وهذا الحارسُ أهمُّ من الأوّل.** `tr()` لا ترمي حين لا تجد: تعيد
  //  العربيَّ كما هو — وهو قرارٌ صحيحٌ على الجهاز (كلمةٌ عربيّةٌ خيرٌ من
  //  فراغٍ) **وكارثيٌّ في التطوير**: يُلفّ النصُّ بـ`tr()` ويُنسى المعجم،
  //  فتبقى الشاشةُ عربيّةً ولا شيءَ يشتكي.
  test('وكلُّ ما نودي به له ترجمة', () {
    final missing = <String>[];

    for (final file in Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final lit in _literals(file.readAsStringSync())) {
        if (!_wrapped(lit) || !_hasArabic(lit.text)) continue;
        if (!englishStrings.containsKey(lit.text)) {
          missing.add('${file.path}:${lit.line} — ${lit.text}');
        }
      }
    }

    expect(missing, isEmpty, reason: 'نصوصٌ مُنادى عليها ولا مدخلَ لها في المعجم');
  });

  // ==========================================================================
  //  ٥) والتغطيةُ لا تنقص — الرقمُ الذي يقول أين نحن
  // ==========================================================================
  //
  //  **وكان يُحسب بتعبيرٍ نمطيٍّ سطريّ.** فنصٌّ يمتدّ سطرين لا يُعدّ، ونصٌّ
  //  في تعليقٍ يُعدّ نصّاً. فصار يُحسب بالمستخرِج نفسِه الذي أعلاه.
  test('وتغطيةُ الترجمة لا تنقص', () {
    var wrapped = 0;
    var loose = 0;

    for (final file in Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // بياناتُ العرض محتوىً لا واجهة، وملفّا اللغة ليسا نصَّ شاشة.
      if (file.path.contains('demo.dart') ||
          file.path.contains('strings_en.dart') ||
          file.path.contains('i18n.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (final lit in _literals(source)) {
        if (!_hasArabic(lit.text)) continue;
        if (_wrapped(lit)) {
          wrapped++;
        } else if (!_excused(lines, lit)) {
          loose++;
        }
      }
    }

    final total = wrapped + loose;
    // ignore: avoid_print
    print('تغطيةُ الترجمة: $wrapped من $total نصّاً '
        '(${(wrapped * 100 / total).round()}٪) — و$loose باقية.');

    expect(wrapped, greaterThanOrEqualTo(coverageFloor),
        reason: 'تراجعت التغطية عمّا كانت');
  });

  // ==========================================================================
  //  ٦) ولا مدخلَ في المعجم لا يُنادى
  // ==========================================================================
  //
  //  معجمٌ يكبر بنصوصٍ لا تُستعمل يوهم بتغطيةٍ لا وجودَ لها — وهو ما كان:
  //  ٢٩٣ مدخلاً وأربعةُ ملفّاتٍ تنادي.
  test('ولا مدخلَ ميّتٌ في المعجم', () {
    final called = <String>{};

    for (final file in Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final lit in _literals(file.readAsStringSync())) {
        if (_wrapped(lit)) called.add(lit.text);
      }
    }

    final dead = englishStrings.keys.where((k) => !called.contains(k)).toList();

    // ولا يُشترط الصفرُ اليوم: المعجمُ سبق النداء، وحذفُ مدخلٍ سيُنادى غداً
    // خسارةٌ لا ربح. فيُقاس العددُ ولا يُترك يكبر.
    expect(
      dead.length,
      lessThanOrEqualTo(deadEntriesCeiling),
      reason: 'مداخلُ ميّتةٌ ازدادت — إمّا أن تُنادى وإمّا أن تُحذف:\n'
          '${dead.take(20).join('\n')}',
    );
  });
}

/// أقلُّ ما بلغته التغطية — يُرفع مع كلّ دفعة، ولا يُنزَل.
const coverageFloor = 120;

/// كم نصّاً عربيّاً أُعفي من الترجمة — واحدٌ اليوم: `' و'` أداةُ التقسيم.
const exemptionsCeiling = 1;

/// سقفُ المداخل الميّتة — يُنقص كلَّما تُرجمت شاشة، ولا يُزاد.
///
/// بدأ ٢٢٥ حين كُتب هذا الملفّ: معجمٌ سبق النداءَ فتفرّقا. وكلُّ شاشةٍ
/// تُترجَم تُنقصه، فحين يبلغ الصفرَ تكون الترجمةُ قد تمّت.
const deadEntriesCeiling = 200;
