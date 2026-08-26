// هويّةُ العلامة: خطٌّ يُشحن فعلاً، وألوانٌ من عائلةٍ واحدة.
//
// **ولماذا اختبارٌ لخطّ:** الخطّ يُذكر في موضعين — `pubspec.yaml` والثيمة —
// وأحدهما يسقط صامتاً. فحذفُ ملفِّ وزنٍ من `assets/fonts` يُسقط البناء
// برسالةٍ صريحة، أمّا حذفُ العائلة من `pubspec.yaml` (أو خطأُ حرفٍ في
// اسمها) فيبني ويعمل: يعود Flutter إلى خطّ النظام بلا كلمةٍ في أي سجل.
//
// وهذا مُجرَّب لا مُقدَّر: حُذفت العائلة من `pubspec.yaml` فمرّت اختبارات
// الشاشات كلُّها خضراء — ولم يلتقطها إلا ما هنا.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';

void main() {
  group('خطّ العلامة', () {
    test('الثيمة تجعله أصلاً لا احتياطاً', () {
      final theme = buildTheme();
      // الأصلُ أوّلاً: لو بقي في `fontFamilyFallback` وحده لسبقه خطُّ الجهاز.
      expect(theme.textTheme.bodyMedium?.fontFamily, brandFont);
      // والاحتياط خلفه لا مكانه: النسخُ يغطّي ما لا يغطّيه Plex.
      expect(arabicFallback, contains('NotoNaskhArabic'));
      expect(arabicFallback.first, brandFont);
    });

    test('وأوزانه الأربعة مذكورةٌ وموجودةٌ على القرص', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $brandFont'));

      for (final weight in [400, 500, 600, 700]) {
        final path = 'assets/fonts/IBMPlexSansArabic-$weight.ttf';
        expect(pubspec, contains(path), reason: 'الوزن $weight غير مذكورٍ في pubspec');
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'الوزن $weight غير موجودٍ على القرص');
        // ملفٌّ فارغٌ أو صفحةُ خطأٍ نُزّلت باسم خطّ: يُذكر ويوجد ولا يعمل.
        expect(file.lengthSync(), greaterThan(50000), reason: 'الوزن $weight أصغر من أن يكون خطّاً');
      }
    });

    test('ويغطّي وحدَه ما تعرضه الشاشات — عربيّةً ولاتينيّةً وترقيماً', () {
      // **وهذا الحارسُ ثمنُ حذف Roboto.** كان مرفقاً لأن نوتو نسخ عربيٌّ
      // خالصٌ لا يحمل «(» ولا «٪» ولا «-»، فكانت «(87)» و«30%» تخرج
      // مربّعاتٍ فارغة. فحُذف حين قِيس أن Plex يحملها — والقياسُ يُعاد هنا
      // في كل تشغيل، لأن **الحرفَ الناقص لا يُسقط بناءً ولا يُكتب في سجلّ:**
      // يظهر مربّعاً في جوال المستخدم وحده.
      final file = File('assets/fonts/IBMPlexSansArabic-400.ttf');
      final bytes = file.readAsBytesSync();
      final covered = _cmapOf(bytes);

      const needed = 'أبجدهوز٠١٢٣٤٥٦٧٨٩ ٪،؛؟ ()[]{}0123456789 %+-–—.,:;!? '
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz '
          'ريال٫';
      final missing = needed
          .runes
          .where((r) => r != 0x20 && !covered.contains(r))
          .map(String.fromCharCode)
          .toList();
      expect(missing, isEmpty, reason: 'محارفُ لا يحملها الخطّ: ${missing.join()}');
    });

    test('ولا خطَّ لاتينيٍّ زائدٍ يُشحن معه', () {
      // Roboto كان ٣٣٦ ك.ب تُشحن في كل حزمة بعد أن صار Plex يغطّي عمله.
      // السطرُ المرفِق لا ذكرُ الاسم: التعليق أعلاه يشرح لماذا حُذف،
      // ولو قِيس بالاسم وحدَه لأسقط هذا الاختبارُ شرحَ نفسِه.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final shipped = RegExp(r'^\s*-\s*asset:.*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m[0]!.trim())
          .toList();
      expect(shipped.any((l) => l.contains('Roboto')), isFalse);
      expect(Directory('assets/fonts')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .length, 5);
    });

    test('ورخصتُه مرفقةٌ معه', () {
      // OFL تشترط أن تُرفق مع الخطّ حيثما وُزّع — والتطبيق يوزّعه.
      final licence = File('assets/fonts/IBMPlexSansArabic-OFL.txt');
      expect(licence.existsSync(), isTrue);
      expect(licence.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });
  });

  group('عائلة اللون', () {
    test('الأسطح دافئةٌ لا مزرقّة', () {
      // القياسُ لا النظر: سطحٌ «دافئ» يعني أحمرَه أعلى من أزرقه. وهذا ما
      // ينقلب بسطرٍ واحدٍ يُلصق من اللوحة الزرقاء فلا يلحظه أحد.
      for (final (name, c) in [
        ('page', AppColors.page),
        ('surface2', AppColors.surface2),
        ('hairline', AppColors.hairline),
        ('ink', AppColors.ink),
        ('ink2', AppColors.ink2),
        ('muted', AppColors.muted),
        ('accent', AppColors.accent),
      ]) {
        expect(c.r, greaterThan(c.b), reason: '«$name» أزرقُه أعلى من أحمره');
      }
    });

    test('والنبيذيّ نبيذيٌّ لا أحمرَ صريح', () {
      // أحمرُ الخطأ وأحمرُ العلامة يجب أن يفترقا: لو تقاربا لقُرئ زرُّ
      // «احجز الآن» تحذيراً.
      final brand = HSLColor.fromColor(AppColors.accent);
      final danger = HSLColor.fromColor(AppColors.critical);
      expect(brand.lightness, lessThan(0.35));
      expect((brand.hue - danger.hue).abs(), greaterThan(20));
    });
  });
}

/// محارفُ الخطّ من جدول `cmap` مباشرةً.
///
/// **قراءةُ الملفّ لا الوثوقُ بوصفه:** «الخطّ يدعم العربية» جملةٌ في صفحة
/// المشروع، والذي يُرسم على الجهاز هو ما في هذا الجدول. وتُقرأ الصيغتان
/// الشائعتان (4 و12) لأن Plex يستعمل الأولى للأساسي والثانية للامتداد.
Set<int> _cmapOf(List<int> b) {
  int u16(int o) => (b[o] << 8) | b[o + 1];
  int u32(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  final tables = u16(4);
  int? cmapOffset;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(b.sublist(rec, rec + 4));
    if (tag == 'cmap') cmapOffset = u32(rec + 8);
  }
  if (cmapOffset == null) return {};

  final out = <int>{};
  final subtables = u16(cmapOffset + 2);
  for (var i = 0; i < subtables; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final sub = cmapOffset + u32(rec + 4);
    final format = u16(sub);

    if (format == 4) {
      final segX2 = u16(sub + 6);
      final ends = sub + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (var s = 0; s < segX2; s += 2) {
        final end = u16(ends + s), start = u16(starts + s);
        if (start == 0xFFFF) continue;
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          final ro = u16(ranges + s);
          if (ro == 0) {
            if ((c + u16(deltas + s)) & 0xFFFF != 0) out.add(c);
          } else {
            final gi = ranges + s + ro + (c - start) * 2;
            if (gi + 1 < b.length && u16(gi) != 0) out.add(c);
          }
        }
      }
    } else if (format == 12) {
      final groups = u32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final o = sub + 16 + g * 12;
        for (var c = u32(o); c <= u32(o + 4); c++) {
          out.add(c);
        }
      }
    }
  }
  return out;
}
