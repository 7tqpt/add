// سهمُ «هذا يُفتح» يشير إلى الأمام — وإلى الأمام في العربيّة يسارٌ.
//
// ── العطبُ الذي كشفته لقطةٌ للشاشة الحقيقيّة ───────────────────────────────
//
// كُتب في `CardTitleBar` ومعه سبعةُ مواضعَ أخرى:
//
//   Directionality.of(context) == TextDirection.rtl
//       ? Icons.chevron_left
//       : Icons.chevron_right
//
// وفي رأسي أنّ الأيقونةَ ثابتةٌ لا تنقلب، فأسألُ الجهةَ بنفسي. **وليست
// ثابتة**: `chevron_left` و`chevron_right` كلتاهما `matchTextDirection: true`
// في Flutter — أي ينقلبان مع اللغة. فكان سؤالُ الجهة انعكاساً ثانياً يُلغي
// الأوّل: تُطلب `chevron_left` في العربيّة فتُرسم `›`.
//
// أي أنّ **كلَّ سهمٍ في التطبيق كان يشير إلى الخلف** — وهو عطبٌ لا يُرى في
// شجرة العناصر ولا في أيّ اختبارٍ كان: الأيقونةُ المطلوبةُ صحيحةُ الاسم،
// والمرسومُ وحدَه مقلوب. ولم يظهر إلّا حين صُوّرت الشاشةُ الحقيقيّةُ بخطوطها.
//
// ── فيُقاس الأمران اللذان يصنعان الاتّجاه ─────────────────────────────────
//
//   ١. **أنّ الأيقونةَ تنقلب مع اللغة** — وهي خاصّةٌ في `IconData` نفسِها،
//      وهي التي أخطأتُ فيها.
//   ٢. **وأنّ المكتوبَ صورتُها اللاتينيّة** (`chevron_right`) — فيتكفّل
//      الإطارُ بقلبها في العربيّة.
//
// وواحدٌ منهما وحدَه لا يقول شيئاً: (٢) بلا (١) تُبقي السهمَ يميناً أبداً،
// و(١) بلا (٢) هي العطبُ نفسُه.
//
// ── ويُمشَّط `lib/` كلُّه ──────────────────────────────────────────────────
//
// المواضعُ ثمانيةٌ في ثمانية ملفّات، ولا شاشةَ تجمعها. فاختبارٌ لواحدةٍ
// يحرس واحدة — **والنصُّ يُقرأ فيُحرس الجميع**، ومن كتب `chevron_left`
// غداً في شاشةٍ جديدةٍ سقط هنا.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

Widget _rtl(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

/// أسطرُ `lib/` التي تذكر أيقونةً بعينها — دون سطور التعليق.
///
/// **والتعليقُ يُستثنى وإلّا حرس الاختبارُ شرحَه هو**: هذه الشيفرةُ موصوفةٌ
/// في ثلاثة تعليقاتٍ تسمّي `chevron_left` بالحرف.
List<String> _mentions(String needle) {
  final hits = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (line.contains(needle)) hits.add('${entity.path}:${i + 1}');
    }
  }
  return hits;
}

void main() {
  group('سهمُ «هذا يُفتح»', () {
    testWidgets('**ينقلب مع اللغة بنفسه**', (tester) async {
      await tester.pumpWidget(_rtl(const AppCard(
        children: [CardTitleBar('قاعة التاج', opens: true)],
      )));

      final icon = tester.widget<Icon>(find.descendant(
        of: find.byType(CardTitleBar),
        matching: find.byType(Icon),
      ));
      expect(icon.icon?.matchTextDirection, isTrue,
          reason: 'أيقونةٌ لا تنقلب مع اللغة — فالسهمُ إلى اليمين في العربيّة');
      expect(icon.icon, Icons.chevron_right,
          reason: 'كُتبت الصورةُ المقلوبةُ بيدٍ، فوقع انعكاسان');
    });

    test('**ولا موضعَ في `lib/` يقلبها بيده**', () {
      expect(_mentions('Icons.chevron_left'), isEmpty,
          reason: 'أيقونةٌ مقلوبةٌ بيدٍ تُرسم إلى الخلف في العربيّة');
    });

    test('**ولا يُسأل الاتّجاهُ لاختيار سهم**', () {
      // السؤالُ نفسُه هو العطب: من سأل قلبَ مرّتين.
      final asked = _mentions('TextDirection.rtl')
          .where((at) => at.contains('kit.dart') || at.contains('screens/'))
          .toList();
      for (final at in asked) {
        final file = at.split(':').first;
        final line = int.parse(at.split(':').last);
        final lines = File(file).readAsLinesSync();
        // النافذةُ ثلاثةُ أسطرٍ بعد السؤال: `? Icons.… : Icons.…`.
        final window = lines.sublist(line - 1, (line + 3).clamp(0, lines.length));
        expect(window.join('\n'), isNot(contains('Icons.chevron')),
            reason: 'في $at: سؤالُ الاتّجاهِ لاختيار سهمٍ انعكاسٌ ثانٍ');
      }
    });
  });
}
