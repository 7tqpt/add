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

  // ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ
  // حارسٌ ثانٍ من الجنس نفسه: مرشِّحٌ يُستقبل ولا يُستعمل.
  //
  // **ولماذا يلزم حارسُ مصدر:** اختبارات الواجهة تجري في وضع العرض، فتقيس
  // الفرعَ الذي يرشّح في الذاكرة وحده. ولو نُسي `.eq` في فرع Supabase لمرّت
  // كلُّها وهي خضراء، ثم يضغط المستخدم «عدن» فتُعرض له خدماتُ صنعاء. جرّبتُه:
  // نزعتُ السطر فمرّ الاختبار كما هو.
  test('كلُّ مرشِّحٍ تستقبله الدالّة يُستعمل في فرع Supabase أيضاً', () {
    final source = _code(File('lib/src/data/api.dart').readAsStringSync());

    for (final name in ['services', 'providers']) {
      final start = source.indexOf('Future<List<');
      expect(start, isNonNegative);
      final body = _bodyOf(source, name);
      expect(body, isNotNull, reason: 'لم أجد الدالّة $name');

      // ما بعد `if (!isSupabaseConfigured)` هو فرعُ القاعدة.
      final split = body!.indexOf('db.from(');
      expect(split, isNonNegative, reason: '$name بلا استعلام قاعدة');
      final remote = body.substring(split);

      expect(remote.contains('governorate'), isTrue,
          reason: 'المحافظة تُستقبل في $name ولا تُستعمل في استعلام القاعدة');
    }
  });
}

/// جسدُ دالّةٍ باسمها — من أوّل `{` بعد الاسم إلى ما يوازنه.
String? _bodyOf(String source, String name) {
  final at = source.indexOf('> $name(');
  if (at < 0) return null;
  // من `async {` لا من أوّل `{`: الأولى قوسُ **المعامِلات المسمّاة**
  // (`services({`)، فمن بدأ منها استخرج قائمة المعامِلات لا الجسد — ووجدها
  // بلا `db.from` فظنّ الدالّة بلا استعلام. وقع بي هذا.
  final async = source.indexOf('async', at);
  if (async < 0) return null;
  final open = source.indexOf('{', async);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i);
    }
  }
  return null;
}

/// الشيفرة بلا أسطر التعليق.
///
/// تُحذف الأسطر التي تبدأ بـ`//` وحدها لا كلُّ ما بعد `//` في أي سطر: الثاني
/// يقصّ داخل النصوص أيضاً — و`'https://…'` فيها شرطتان.
String _code(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');
