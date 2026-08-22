// حارسُ الترتيب.
//
// **العطب الذي بُني هذا الملف لأجله:** `postgrest` في Dart افتراضُها
// `ascending: false` — أي أن `.order('created_at')` تعني **نزولاً**. وهي عكسُ
// نظيرتها في JavaScript (‏`ascending = true`‏)، فمن قرأ وثائق Supabase أو نقل
// سطراً من اللوحة إلى التطبيق وقع فيها بلا أن يرى شيئاً.
//
// ووقعت في تسعة مواضع: خيطُ المحادثة كان يُقرأ من أسفل إلى أعلى، والأقسام
// الاثنا عشر معكوسة، والحجوزات أبعدُها موعداً أوّلاً، ورسائل الدعم كذلك.
//
// **ولماذا لم يكشفها اختبارٌ واحد:** وضع العرض يرتّب في الذاكرة ولا يمرّ
// بـ`postgrest` أصلاً. أي أن الطريق الذي انكسر هو الطريق الوحيد الذي لا
// تسلكه الاختبارات — وهو الطريق الذي يسلكه المستخدم وحده.
//
// فالحارس يقرأ المصدر نفسه: لا يحتاج شبكةً ولا خادماً، ويسقط عند أوّل
// `order` بلا `ascending`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('كلُّ order في api.dart يذكر ascending صراحةً', () {
    // التعليقات تُطرح أولاً — وإلّا أسقط الحارسُ نفسَه: التعليق الذي يشرح
    // هذا العطب في `api.dart` يذكر `.order('created_at')` نصّاً، فيقرؤه
    // الحارس نداءً بلا `ascending`. وقد وقع.
    final source = _code(File('lib/src/data/api.dart').readAsStringSync());

    // تُطوى الأسطر لأن النداء قد يمتدّ على أكثر من سطر.
    final flat = source.replaceAll(RegExp(r'\s+'), ' ');
    final calls = RegExp(r'\.order\(([^)]*)\)').allMatches(flat);

    expect(calls, isNotEmpty, reason: 'لم يُعثر على أي order — هل تغيّر الملف؟');

    final naked = calls
        .map((m) => m.group(1)!.trim())
        .where((args) => !args.contains('ascending:'))
        .toList();

    expect(
      naked,
      isEmpty,
      reason:
          'هذه النداءات تُرتّب **نزولاً** وهي لا تقول ذلك:\n'
          '${naked.map((a) => '  .order($a)').join('\n')}\n\n'
          'اكتب `ascending: true` أو `ascending: false` — الافتراض في Dart '
          'نزوليّ، وهو عكس JavaScript.',
    );
  });

  test('وترتيب الرسائل صعوديّ — وإلّا قُرئ الخيط مقلوباً', () {
    // لا يكفي أن يُذكر `ascending`؛ فذكرُه بـ`false` في المحادثة يعيد العطب
    // نفسه وقد مرّ من الحارس أعلاه.
    final flat = _code(File('lib/src/data/api.dart').readAsStringSync())
        .replaceAll(RegExp(r'\s+'), ' ');

    for (final table in ['conversation_messages', 'support_messages']) {
      final section = RegExp("from\\('$table'\\).*?;").firstMatch(flat)?.group(0);
      expect(section, isNotNull, reason: 'لم يُعثر على استعلام $table');
      expect(
        section,
        contains("order('created_at', ascending: true)"),
        reason: '$table يجب أن يُرتَّب صعوداً: الأقدم أعلى والأحدث أسفل.',
      );
    }
  });
}

/// الشيفرة بلا أسطر التعليق.
///
/// تُحذف الأسطر التي تبدأ بـ`//` وحدها لا كلُّ ما بعد `//` في أي سطر: الثاني
/// يقصّ داخل النصوص أيضاً — و`'https://…'` فيها شرطتان.
String _code(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');
