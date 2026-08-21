import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// التنسيق العربي — أرقام لاتينية وتقويم ميلادي، كما في اللوحة.
///
/// «ar» لا «ar_EG»: الثانية تُخرج أرقاماً هنديّة (١٤٥٬٨٧٣) فتختلف الأسعار في
/// التطبيق عن اللوحة، والرقم اللاتيني أوضح بجوار الساعات وأرقام الحجوزات.
final _int = NumberFormat.decimalPattern('ar');
final _month = DateFormat('MMMM', 'ar');

/// تهيئة أسماء الشهور العربية. بدونها يرمي أوّل تاريخٍ يُعرض
/// `LocaleDataException` — والمحلّل الساكن لا يرى ذلك، فالخطأ يقع وقت التشغيل.
Future<void> initFormatting() => initializeDateFormatting('ar');

String formatNumber(num n) => _int.format(n);

/// الريال اليمني. اللاحقة تُضاف يدوياً: رمز CLDR يحمل نقطةً تقذفها خوارزمية
/// البيدي إلى الطرف الخطأ من الرقم.
String formatMoney(num n) => '${_int.format(n)} ر.ي';

/// «10 سبتمبر 2026» — اسم الشهر عربي والأرقام لاتينية.
///
/// يُركَّب اليوم والسنة يدوياً لأن `DateFormat('d MMMM yyyy', 'ar')` يكتبهما
/// بالأرقام الهندية (١٠ سبتمبر ٢٠٢٦)، فيقع في الشاشة الواحدة نظاما أرقام:
/// تاريخٌ هندي بجوار سعرٍ لاتيني.
String formatDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_month.format(d)} ${d.year}';
}

/// "20:00" → "8:00 م". الأوقات تُخزَّن نصّاً بصيغة HH:MM.
String formatTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parts = value.split(':');
  final h = int.tryParse(parts.first);
  if (h == null) return value;
  final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
  final period = h < 12 ? 'ص' : 'م';
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:$m $period';
}

/// صيغ الاسم المعدود الأربع: مفرد، مثنّى، جمع قلّة، تمييز مفرد.
///
/// المطابقة في العربية ليست إضافة حرف: الاثنان لهما صيغتهما ويسقط معهما العدد،
/// و٣–١٠ جمع قلّة، و١١ فصاعداً تمييز مفرد منصوب. وكتابة «2 يوم» نصٌّ مكسور لا
/// تقريبٌ مقبول.
String formatCount(int count, ({String one, String two, String few, String many}) forms) {
  final n = count.abs();
  if (n == 1) return forms.one;
  if (n == 2) return forms.two;
  if (n >= 3 && n <= 10) return '${_int.format(n)} ${forms.few}';
  return '${_int.format(n)} ${forms.many}';
}

const dayForms = (one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوماً');
const hourForms = (one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة');
const minuteForms = (one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة');
const guestForms = (one: 'ضيف واحد', two: 'ضيفان', few: 'ضيوف', many: 'ضيفاً');
const bookingForms = (one: 'حجزٌ واحد', two: 'حجزان', few: 'حجوزات', many: 'حجزاً');

/// «منذ ٣ ساعات» للماضي و«بعد ٧ أيام» للمستقبل.
String formatRelative(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final diff = DateTime.now().difference(d);
  final future = diff.isNegative;
  final abs = diff.abs();
  final prefix = future ? 'بعد' : 'منذ';

  // التقريب لا البتر: `inDays` يبتر نحو الصفر، فموعدٌ بعد سبعة أيام يقع قبله
  // بميكروثانية عن لحظة القياس فيُقرأ «بعد 6 أيام». والبتر في اتجاه المستقبل
  // يُنقص دائماً، أي أنه يعد التاريخ أقرب مما هو.
  final minutes = (abs.inSeconds / 60).round();
  if (minutes < 1) return 'الآن';
  if (minutes < 60) return '$prefix ${formatCount(minutes, minuteForms)}';
  final hours = (minutes / 60).round();
  if (hours < 24) return '$prefix ${formatCount(hours, hourForms)}';
  final days = (hours / 24).round();
  if (days < 30) return '$prefix ${formatCount(days, dayForms)}';
  return formatDate(iso);
}
