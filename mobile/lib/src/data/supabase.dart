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
/// رمزُ العطب — **ولو لم يصل نوعاً**.
///
/// **وهذا ما كان مكسوراً:** الاكتفاءُ بـ`PostgrestException` كان يعيد `null`
/// لكلّ عطبٍ يصل من مسلكٍ آخر (المصادقة، أو ردٌّ خامٌ من الخادم). ووقع ذلك
/// فعلاً على جهاز: ردٌّ فيه `"code":"PGRST303"` صريحاً، فقُرئ بلا رمز.
///
/// وأثرُه ثلاثةٌ لا واحد:
///
///   ١. عُرض على صاحبه نصُّ JSON خاماً.
///   ٢. وقيل له «الغالب أنّ ملفات المخطّط لم تُطبَّق» — وهو تشخيصٌ كاذب،
///      يُرسله إلى مجلّدٍ سليمٍ يبحث فيه.
///   ٣. **ولم يعمل الإصلاحُ الذاتيّ أصلاً**: `_healClockSkew` مشروطٌ بهذا
///      الرمز، فلمّا غاب لم يُحاوَل شيء. ميزةٌ مبنيّةٌ وميّتة.
///
/// فيُقرأ الرمزُ من النوع إن وُجد، ثمّ من نصّ الردّ، ثمّ من الرسالة المعروفة.
String? errorCodeOf(Object error) {
  if (error is PostgrestException && error.code != null) return error.code;

  final text = error.toString();
  // `"code":"PGRST303"` — كما يردّه PostgREST في جسم الردّ.
  final coded = RegExp(r'"code"\s*:\s*"([A-Za-z0-9]+)"').firstMatch(text);
  if (coded != null) return coded.group(1);

  // وبالرسالة حين لا رمزَ فيها: بعض المسالك تُسقط الجسمَ وتُبقي النصّ.
  if (text.contains('JWT issued at future')) return jwtIssuedAtFuture;
  return null;
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
  if (text.isEmpty) return 'تعذّر تنفيذ الطلب.';

  // **ولا يُعرض JSON خامٌ على أحد.** ردٌّ مثل
  // `{"message":"JWT issued at future","code":"PGRST303",…}` وقع على شاشة
  // مستخدمٍ فعلاً. ومن رأى أقواساً وعلاماتِ اقتباسٍ لا يقرأ منها شيئاً، ولا
  // يعرف أنّ ساعةَ جهازه هي السبب.
  final message = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(text);
  if (message != null) {
    final body = message.group(1)!.replaceAll(r'\"', '"');
    if (body.trim().isNotEmpty) return body;
  }
  return text;
}
