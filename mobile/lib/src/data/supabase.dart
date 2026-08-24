import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';

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

/// رمزُ PostgREST حين يرى الرمزَ «صادراً في المستقبل».
///
/// أي أن ساعةَ من أصدر الرمز تسبق ساعةَ من يقرؤه. وهو فرقُ ثوانٍ في العادة
/// يمضي وحده، ولذلك يُعالَج بإعادة المحاولة لا برسالةِ عطبٍ نهائية.
const jwtIssuedAtFuture = 'PGRST303';

/// فرقُ الساعة بين هذا الجهاز والخادم — موجبٌ إن كان الجهاز **متقدّماً**.
///
/// **ولماذا يُقاس ولا يُخمَّن:** «فرقٌ في الساعة» جملةٌ لا تدلّ على من يُصلح
/// ماذا. وترويسة `Date` في أي ردٍّ من الخادم تقول وقتَه بالضبط، فيُطرح منها
/// وقتُ الجهاز ويُقال الرقم: «ساعة جوالك تسبق الخادم بسبع دقائق» — وهذه
/// جملةٌ تُفعَل.
///
/// وتُعيد `null` إن تعذّر الوصول أو غابت الترويسة: عجزٌ عن القياس لا يُقال
/// رقماً خاطئاً.
Future<Duration?> clockSkew() async {
  if (!isSupabaseConfigured) return null;
  try {
    // نقطةُ الصحّة لا تحتاج رمزاً ولا تكتب شيئاً — وردُّها يحمل الترويسة.
    final res = await http
        .get(Uri.parse('$supabaseUrl/auth/v1/health'), headers: {'apikey': supabaseAnonKey})
        .timeout(const Duration(seconds: 8));
    final date = res.headers['date'];
    if (date == null) return null;
    final server = parseHttpDate(date).toUtc();
    return DateTime.now().toUtc().difference(server);
  } catch (_) {
    return null;
  }
}

/// وصفُ الفرق بالعربية، أو `null` إن كان صغيراً لا يُذكر.
String? clockSkewLabel(Duration? skew) {
  if (skew == null) return null;
  final seconds = skew.inSeconds;
  if (seconds.abs() < 30) return null;
  final amount = seconds.abs() >= 3600
      ? formatCount(seconds.abs() ~/ 3600, hourForms)
      : seconds.abs() >= 60
      ? formatCount(seconds.abs() ~/ 60, minuteForms)
      : formatCount(seconds.abs(), secondForms);
  return seconds > 0
      ? 'ساعةُ جوالك **تسبق** الخادم بـ$amount.'
      : 'ساعةُ جوالك **متأخّرة** عن الخادم بـ$amount.';
}

/// رمزُ الخطأ كما جاء من الخادم، إن كان له رمز.
///
/// يُقارَن به لا بنصّ الرسالة: النصّ إنجليزيٌّ يتغيّر بين الإصدارات، والرمز
/// جزءٌ من الواجهة.
String? errorCodeOf(Object error) => error is PostgrestException ? error.code : null;

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
