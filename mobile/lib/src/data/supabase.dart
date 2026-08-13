import 'package:supabase_flutter/supabase_flutter.dart';

/// رابط المشروع ومفتاحه — يُمرَّران عند البناء لا في الشيفرة:
///
///   flutter run --dart-define-from-file=env.json
///
/// والمفتاح هو publishable/anon وحده. مصمَّمٌ ليعيش في الأجهزة: التطبيق المنشور
/// يمكن فكّه واستخراج ما فيه، فالحماية في سياسات RLS لا في إخفاء المفتاح.
/// ولا يوضع `service_role` هنا أبداً — يتجاوز السياسات كلها.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

SupabaseClient get db => Supabase.instance.client;

Future<void> initSupabase() async {
  if (!isSupabaseConfigured) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

/// يستخرج رسالةً مقروءة مما رُمي.
///
/// Supabase يرفض بأنواع خاصة لا بـ Exception عامة، والاكتفاء بالنوع العام يبتلع
/// كل أخطاء القاعدة ويعرض جملةً لا تدلّ على شيء. نصّ الخطأ يسمّي الجدول أو
/// الدالة الناقصة بالضبط.
String messageOf(Object error) {
  if (error is PostgrestException) {
    final hint = error.hint == null ? '' : ' — ${error.hint}';
    final code = error.code == null ? '' : '[${error.code}] ';
    return '$code${error.message}$hint';
  }
  if (error is AuthException) {
    return error.message == 'Invalid login credentials'
        ? 'بيانات الدخول غير صحيحة.'
        : error.message;
  }
  final text = error.toString();
  return text.isEmpty ? 'تعذّر تنفيذ الطلب.' : text;
}
