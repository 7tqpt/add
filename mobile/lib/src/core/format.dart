import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'i18n.dart';

/// التنسيق العربي — أرقام لاتينية وتقويم ميلادي، كما في اللوحة.
///
/// «ar» لا «ar_EG»: الثانية تُخرج أرقاماً هنديّة (١٤٥٬٨٧٣) فتختلف الأسعار في
/// التطبيق عن اللوحة، والرقم اللاتيني أوضح بجوار الساعات وأرقام الحجوزات.
final _int = NumberFormat.decimalPattern('ar');

/// **واسمُ الشهر يأتي من `DateFormat` بلغته لا من معجم.**
///
/// «سبتمبر» تُترجَم `September` بمدخلٍ في المعجم، وكذلك أحدَ عشرَ اسماً
/// غيرَها — ثمّ تأتي أسماءُ الأيّام. وهذه بيانات لغةٍ تحملها `intl` كاملةً
/// ومراجَعةً، فطلبُها منها أصحُّ من نسخها بأيدينا.
///
/// ودالّةٌ لا ثابت: اللغةُ تتبدّل والتطبيقُ يعمل.
DateFormat get _month => DateFormat('MMMM', _intlLocale);

String get _intlLocale => appLocale.value == AppLocale.en ? 'en' : 'ar';

/// تهيئة أسماء الشهور. بدونها يرمي أوّل تاريخٍ يُعرض `LocaleDataException` —
/// والمحلّل الساكن لا يرى ذلك، فالخطأ يقع وقت التشغيل.
///
/// **واللغتان معاً**: تبديلُ اللغة لا ينتظر تهيئةً ثانية.
Future<void> initFormatting() async {
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
}

String formatNumber(num n) => _int.format(n);

/// الريال اليمني. اللاحقة تُضاف يدوياً: رمز CLDR يحمل نقطةً تقذفها خوارزمية
/// البيدي إلى الطرف الخطأ من الرقم.
String formatMoney(num n) => trf('{0} ر.ي', [_int.format(n)]);

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
  final period = h < 12 ? tr('ص') : tr('م');
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:$m $period';
}

/// ساعةُ طابعٍ زمني كامل — «٨:٠٠ م» من `2026-09-15T20:00:00Z`.
///
/// والتحويل إلى التوقيت المحلي أوّلاً: الطابع من Postgres بتوقيت UTC، وعرضُه
/// كما هو يُظهر رسالةً كُتبت الثامنة مساءً على أنها الخامسة.
String formatTimeOf(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final local = d.toLocal();
  return formatTime('${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}');
}

/// صيغُ الاسم المعدود.
///
/// **وهذا هو الموضعُ الوحيدُ في التطبيق الذي لا تكفيه `tr()`.**
///
/// العربيّةُ أربعُ صيغ: مفردٌ («يوم»)، ومثنّىً يسقط معه العدد («يومين»)،
/// وجمعُ قلّةٍ لثلاثةٍ إلى عشرة («٣ أيام»)، وتمييزٌ مفردٌ منصوبٌ لما فوقها
/// («١١ يوماً»). والإنجليزيّةُ صيغتان: واحدةٌ وما سواها.
///
/// ولو تُرجمت الصيغُ الأربعُ مداخلَ في المعجم لَخرجت الإنجليزيّةُ من فرعٍ
/// عربيّ: «يومين» تُختار للاثنين ثمّ تُترجَم `two days` — فيصحّ النصُّ
/// صدفةً وتبقى البنيةُ خاطئة، وتنكسر عند أوّل معدودٍ لا يطّرد.
///
/// **فالتفريعُ باللغة نفسِها**، وكلُّ معدودٍ يحمل صيغَه في اللغتين.
typedef CountForms = ({
  String one,
  String two,
  String few,
  String many,
  String enOne,
  String enMany,
});

String formatCount(int count, CountForms forms) {
  final n = count.abs();

  if (appLocale.value == AppLocale.en) {
    return n == 1 ? forms.enOne : '${_int.format(n)} ${forms.enMany}';
  }

  if (n == 1) return forms.one;
  if (n == 2) return forms.two;
  if (n >= 3 && n <= 10) return '${_int.format(n)} ${forms.few}';
  return '${_int.format(n)} ${forms.many}';
}

const dayForms = (one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوماً',
    enOne: 'one day', enMany: 'days');
const taskForms = (one: 'مهمّةٌ واحدة', two: 'مهمّتان', few: 'مهامّ', many: 'مهمّة',
    enOne: 'one task', enMany: 'tasks');
const hourForms = (one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة',
    enOne: 'an hour', enMany: 'hours');
const minuteForms = (one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة',
    enOne: 'a minute', enMany: 'minutes');
const guestForms = (one: 'ضيف واحد', two: 'ضيفان', few: 'ضيوف', many: 'ضيفاً',
    enOne: 'one guest', enMany: 'guests');
const bookingForms = (one: 'حجزٌ واحد', two: 'حجزان', few: 'حجوزات', many: 'حجزاً',
    enOne: 'one booking', enMany: 'bookings');
const secondForms = (one: 'ثانية', two: 'ثانيتان', few: 'ثوانٍ', many: 'ثانية',
    enOne: 'a second', enMany: 'seconds');
const reviewForms = (one: 'تقييمٍ واحد', two: 'تقييمين', few: 'تقييمات', many: 'تقييماً',
    enOne: 'one review', enMany: 'reviews');

/// مدّة مقطع. والدقيقة تُسمّى دقيقةً لا «٦٠ ثانية».
String formatSeconds(int seconds) {
  if (seconds >= 60 && seconds % 60 == 0) return formatCount(seconds ~/ 60, minuteForms);
  if (seconds < 60) return formatCount(seconds, secondForms);
  return trf('{0} و{1}',
      [formatCount(seconds ~/ 60, minuteForms), formatCount(seconds % 60, secondForms)]);
}

/// «٠:٤٨» — للمشغّل وحده حيث يتغيّر الرقم كل ثانية.
String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// حجم ملف. الوحدة عربية لأنها تُقرأ لا تُنسخ.
String formatBytes(int bytes) {
  if (bytes < 1024) return trf('{0} بايت', ['$bytes']);
  if (bytes < 1024 * 1024) return trf('{0} ك.ب', ['${(bytes / 1024).round()}']);
  final mb = bytes / (1024 * 1024);
  // منزلةٌ واحدة تحت العشرة وصحيحٌ فوقها: «١٫٤ م.ب» تفيد، و«٤٨٫٣ م.ب» لا
  // تزيد على «٤٨» شيئاً.
  return mb < 10
      ? trf('{0} م.ب', [mb.toStringAsFixed(1)])
      : trf('{0} م.ب', ['${mb.round()}']);
}

/// «منذ ٣ ساعات» للماضي و«بعد ٧ أيام» للمستقبل.
String formatRelative(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final diff = DateTime.now().difference(d);
  final future = diff.isNegative;
  final abs = diff.abs();

  // **ولا يُبنى النصُّ بالجمع.** «منذ» و«بعد» سابقتان في العربيّة، ومكانُهما
  // في الإنجليزيّة لاحقةٌ في إحداهما وسابقةٌ في الأخرى: «3 hours ago» و«in 3
  // hours». فلو لُصق حرفٌ بعددٍ لَخرجت «ago 3 hours».
  String said(String amount) =>
      future ? trf('بعد {0}', [amount]) : trf('منذ {0}', [amount]);

  // التقريب لا البتر: `inDays` يبتر نحو الصفر، فموعدٌ بعد سبعة أيام يقع قبله
  // بميكروثانية عن لحظة القياس فيُقرأ «بعد 6 أيام». والبتر في اتجاه المستقبل
  // يُنقص دائماً، أي أنه يعد التاريخ أقرب مما هو.
  final minutes = (abs.inSeconds / 60).round();
  if (minutes < 1) return tr('الآن');
  if (minutes < 60) return said(formatCount(minutes, minuteForms));
  final hours = (minutes / 60).round();
  if (hours < 24) return said(formatCount(hours, hourForms));
  final days = (hours / 24).round();
  if (days < 30) return said(formatCount(days, dayForms));
  return formatDate(iso);
}

/// «20 مايو 2027» من `DateTime` لا من نصّ — التقويم يعمل على تواريخ لا سلاسل.
String formatDay(DateTime d) => '${d.day} ${_month.format(d)} ${d.year}';

/// «مايو 2027» — رأس شبكة الشهر.
String formatMonth(DateTime d) => '${_month.format(d)} ${d.year}';

/// الفرق بالأيام التقويمية لا بالساعات.
///
/// `DateTime.difference` يحسب بالساعات ثم يقسم، فعرسٌ غداً ظهراً يخرج «صفر
/// يوم» إن نُظر إليه صباحاً. والمستخدم يعدّ الأيام لا الساعات.
///
/// وهنا لا في شاشة: العدُّ التنازلي يظهر في الرئيسية وفي منظِّم الحفل معاً،
/// ونسخةٌ ثانيةٌ منه تفترق عن أصلها عند أوّل تصحيح.
int? daysUntil(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return null;
  final now = DateTime.now();
  return DateTime(date.year, date.month, date.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

/// «بقي ٧ أيام» — والعدد يُصرَّف، فلا يُكتب «بقي 3 يوماً».
String countdownLabel(int? days) {
  if (days == null) return '—';
  if (days > 1) return trf('بقي {0}', [formatCount(days, dayForms)]);
  if (days == 1) return tr('غداً بإذن الله');
  if (days == 0) return tr('اليوم — مبارك!');
  return trf('مضى {0}', [formatCount(-days, dayForms)]);
}
