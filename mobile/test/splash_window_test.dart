// نافذةُ الإقلاع — ما يرسمه أندرويد قبل أن يقلع Flutter.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «عند ضغط على التطبيق بداية الإقلاع يطلع أبيض» — ومعها لقطةٌ لشاشةٍ بيضاء.
// واختار (ب): نبيذيٌّ وعليه العلامة.
//
// ── ولماذا اختبارٌ يقرأ ملفّات XML ─────────────────────────────────────────
//
// **هذه النافذةُ لا تُصوَّر ولا تُبنى في حزمةٍ**: يرسمها أندرويد قبل أن
// يقلع محرّك Flutter، فلا `pumpWidget` يبلغها ولا `toImage`. وما لا يُقاس
// يعود بعد جولتين: العطبُ الأصليُّ كان ملفَّين بالاسم نفسِه، أحدُهما
// صحيحٌ لا يراه جهازٌ حديثٌ والآخرُ أبيضُ يراه الجميع — وبقي سنةً ولم
// ينبّه إليه شيء.
//
// فتُقرأ الموارد. وليس هذا قياساً ضعيفاً: الموردُ **هو** المنتج هنا، ولا
// شيءَ بينه وبين ما يُرسم على الزجاج.
//
// ── وأخطرُ ما يُقاس: لونان مكتوبان بيدٍ في ملفّين ─────────────────────────
//
// `#5C0820` مكتوبٌ في `colors.xml` وفي `AppColors.accentDeep` في
// `theme.dart`. وافتراقُهما لا يُسقط بناءً ولا يحمّر اختباراً — يظهر
// ومضةً في عُشر ثانيةٍ عند كلّ إقلاع، ولا يراها من عدّلها.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

final _res = Directory('android/app/src/main/res');

String _read(String path) {
  final file = File('${_res.path}/$path');
  expect(file.existsSync(), isTrue, reason: 'لا ملفَّ $path');
  return file.readAsStringSync();
}

/// اللونُ كما يكتبه أندرويد — `#RRGGBB` بحروفٍ كبيرة.
String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// قيمةُ لونٍ مسمّى في `colors.xml`.
String? _colorValue(String name) => RegExp(
      '<color name="$name">([^<]+)</color>',
    ).firstMatch(_read('values/colors.xml'))?.group(1);

void main() {
  group('نافذةُ الإقلاع', () {
    test('**ليست بيضاءَ ولا تسأل النظامَ عن لونه**', () {
      // `?android:colorBackground` في `Theme.Light.NoTitleBar` أبيض — وهو
      // العطبُ بعينه. ويُمشَّط `res/` كلُّه لا ملفٌّ بعينه: العطبُ الأصليُّ
      // كان في ملفٍّ لم يكن أحدٌ ينظر إليه.
      for (final entity in _res.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.xml')) continue;
        // **والتعليقاتُ تُنزع أوّلاً**: هذه الشيفرةُ موصوفةٌ في تعليقٍ
        // يسمّي العطبَ بالحرف، فلولا النزعُ لَسقط الأساسُ على شرحه هو.
        final text = entity
            .readAsStringSync()
            .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
        expect(text, isNot(contains('?android:colorBackground')),
            reason: '${entity.path}: نافذةٌ تسأل النظامَ عن لونه فتخرج بيضاء');
      }
    });

    test('**ولا ملفَّ ثانياً بالاسم نفسِه يغلب المرئيَّ**', () {
      // ملفّان بالاسم نفسِه يفترقان مع الوقت، ويُعدَّل المرئيُّ منهما ويبقى
      // الآخر. وهو ما وقع: `drawable-v21/launch_background.xml` كان يغلب
      // `drawable/launch_background.xml` على كلّ جهازٍ بعد ٢٠١٤.
      final twins = _res
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/launch_background.xml'))
          .where((f) => f.existsSync())
          .toList();
      expect(twins.length, 1,
          reason: 'نافذةُ الإقلاع مكتوبةٌ في ${twins.length} ملفّاً: '
              '${twins.map((f) => f.path).join('، ')}');
      expect(twins.single.path, endsWith('drawable/launch_background.xml'));
    });

    test('**وفيها اللونُ والعلامةُ معاً**', () {
      final xml = _read('drawable/launch_background.xml');
      expect(xml, contains('@color/brand_splash'), reason: 'لا لونَ في النافذة');
      expect(xml, contains('@drawable/launch_mark'), reason: 'لا علامةَ في النافذة');
      expect(xml, contains('android:gravity="center"'),
          reason: 'العلامةُ تُمدّ على الشاشة بدل أن تتوسّطها');
    });

    test('**ولونُها لونُ الشاشة التي تليها بعينه**', () {
      // `BootScreen` تدرّجٌ طرفُه `accentDeep`. ولو افترقا لَومضت النافذةُ
      // لوناً غيرَ لون الشاشة في كلّ إقلاع.
      expect(_colorValue('brand_splash'), _hex(AppColors.accentDeep.toARGB32()),
          reason: 'لونُ النافذة غيرُ `AppColors.accentDeep`');
    });

    test('**وما بعدها لا يومض فاتحاً**', () {
      // `NormalTheme` هي خلفيّةُ النافذة بعد أن يقلع المحرّك وقبل أوّل إطار.
      // كانت كريماً فكانت ومضةً فاتحةً بين نبيذيَّين.
      for (final path in [
        'values/styles.xml',
        'values-night/styles.xml',
        'values-v31/styles.xml',
        'values-night-v31/styles.xml',
      ]) {
        final normal = RegExp(
          r'<style name="NormalTheme"[\s\S]*?</style>',
        ).firstMatch(_read(path))?.group(0);
        expect(normal, isNotNull, reason: '$path: لا `NormalTheme`');
        expect(normal, contains('@color/brand_splash'),
            reason: '$path: ما بعد النافذة ليس بلونها');
      }
    });

    test('**وأندرويد ١٢ لا يعود إلى بياضه**', () {
      // من أندرويد ١٢ يرسم النظامُ شاشةَ إقلاعٍ من عنده قبل نافذتنا، ولا
      // يأخذ لونَها من `windowBackground` إلّا إن كان لوناً مفرداً — وصار
      // عندنا `layer-list`. فلولا هذا لَبقيت الشكوى قائمةً على جوّاله.
      for (final path in ['values-v31/styles.xml', 'values-night-v31/styles.xml']) {
        final launch = RegExp(
          r'<style name="LaunchTheme"[\s\S]*?</style>',
        ).firstMatch(_read(path))?.group(0);
        expect(launch, isNotNull, reason: '$path: لا `LaunchTheme`');
        expect(launch, contains('android:windowSplashScreenBackground'),
            reason: '$path: شاشةُ أندرويد ١٢ بلا لون — تعود بيضاء');
        expect(launch, contains('@color/brand_splash'));
      }
    });

    testWidgets('**وترتفع العلامةُ بقدر ارتفاعها في الشاشة التي تليها**',
        (tester) async {
      // **وهذه تنكسر بصمت**: العلامةُ تُرى في النافذة وتُرى في الشاشة،
      // وكلتاهما سليمةٌ وحدَها — والعيبُ قفزةٌ صغيرةٌ بينهما لا يُعرف
      // سببُها، ولا تظهر إلّا في جهازٍ يُفتح.
      //
      // **والرقمُ يُقاس من الشاشة نفسِها لا يُكتب حفظاً.** لو كُتب رقماً
      // لَبقي كما هو حين يتبدّل تخطيطُ `BootScreen` — وهي حُرّةٌ أن تتبدّل.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: BootScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 900));

      final height = tester.getSize(find.byType(BootScreen)).height;
      final markCy = tester.getCenter(find.byType(Image)).dy;
      final rise = height / 2 - markCy;
      expect(rise, greaterThan(0),
          reason: 'العلامةُ في الشاشة لا ترتفع عن الوسط — فلمَ ترتفع في النافذة؟');

      final xml = _read('drawable/launch_background.xml')
          .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
      final inset = RegExp(r'android:bottom="(\d+)dp"').firstMatch(xml)?.group(1);
      expect(inset, isNotNull, reason: 'العلامةُ في النافذة متوسّطةٌ تماماً');
      // الحشوةُ من الأسفل ترفع المركزَ نصفَها.
      expect(int.parse(inset!) / 2, closeTo(rise, 1.5),
          reason: 'العلامةُ ترتفع ${int.parse(inset) / 2} نقطةً في النافذة '
              'و$rise في الشاشة — فتقفز عند أوّل إطار');
    });

    test('**والعلامةُ موجودةٌ في الكثافات الخمس بمقاساتها**', () {
      // كثافةٌ تُنسى تخرج علامةً مشوّهةً على طرازٍ واحدٍ من الأجهزة لا
      // يملكه أحدٌ في الفريق — وهو عينُ ما يحرسه `make_icons.py`.
      const ladder = {
        'mdpi': 104,
        'hdpi': 156,
        'xhdpi': 208,
        'xxhdpi': 312,
        'xxxhdpi': 416,
      };
      for (final entry in ladder.entries) {
        final file = File('${_res.path}/drawable-${entry.key}/launch_mark.png');
        expect(file.existsSync(), isTrue, reason: 'لا علامةَ لكثافة ${entry.key}');
        // **ويُقاس عرضُ الصورة لا وجودُ الملفّ**: ملفٌّ فارغٌ أو مقاسٌ خطأ
        // يُبنى ويعمل ويخرج مشوّهاً. والعرضُ في ترويسة PNG عند البايت ١٦.
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(1000), reason: '${entry.key}: ملفٌّ أصغرُ من صورة');
        final width = bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19];
        expect(width, entry.value,
            reason: '${entry.key}: العلامةُ $width بكسلاً لا ${entry.value}');
      }
    });
  });
}
