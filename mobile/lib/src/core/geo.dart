/// الموقع على الخريطة: نقطةٌ تُقرأ من رابط، وتُفتح في خرائط الجهاز.
///
/// **ولا مفتاحَ خرائطٍ في شيءٍ من هذا.** المفتاح مالٌ شهريٌّ وحسابُ فوترة،
/// وما يُحتاج إليه فعلاً — أن يصل المصوّر إلى بيت العرس — يقع بلا مفتاح:
/// الخريطةُ تُرسم من بلاطات OpenStreetMap، والملاحةُ تُسلَّم إلى تطبيق
/// الخرائط في الجهاز.
library;

import 'dart:math' as math;

/// نقطةٌ على الأرض.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// أهي نقطةٌ ممكنةٌ على الأرض؟
  ///
  /// **وصفرٌ صفرٌ ليست نقطة:** هي «جزيرة نُل» في خليج غينيا — وما يصل إليها
  /// في تطبيقٍ يمنيّ إنّما هو حقلٌ لم يُملأ فقُرئ صفراً. فتُردّ ككلّ ما هو
  /// خارج المدى.
  bool get isValid =>
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0) &&
      !lat.isNaN &&
      !lng.isNaN;

  /// ستُّ خاناتٍ عشرية — دقّةُ نحو عشرة سنتيمترات، وهي ما تحفظه القاعدة.
  String get text => '${lat.toStringAsFixed(6)}، ${lng.toStringAsFixed(6)}';

  @override
  String toString() => '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// يقرأ نقطةً من رابطٍ أو نصٍّ لُصق في الحقل، أو `null` إن لم يجد.
///
/// **ولماذا يُقبل اللصقُ أصلاً:** هكذا تُتبادل المواقع هنا فعلاً — يُرسل
/// الموقعُ في واتساب فيصل رابطاً، ويُنسخ ويُلصق. ومن كان موقعُه في يده رابطاً
/// لا يُطالَب بأن يبحث عنه على خريطةٍ من جديد.
///
/// ويُقبل من الأشكال ما يحمل الرقمين صراحةً:
///
///   * `https://www.google.com/maps/place/…/data=…!3d15.354722!4d44.206667`
///   * `https://www.google.com/maps/@15.354722,44.206667,17z`
///   * `https://maps.google.com/?q=15.354722,44.206667`
///   * `geo:15.354722,44.206667`
///   * `15.354722, 44.206667` — لصقٌ مجرّد
///
/// **ولا يُقبل الرابطُ المختصر** (`maps.app.goo.gl/…`): لا رقمَ فيه أصلاً،
/// وقراءتُه تحتاج نداءَ شبكةٍ يتبع التحويلة. وهذا مقصودٌ هنا: الدالّة نقيّةٌ
/// تُقاس بلا شبكة، ومن لصق مختصراً يُقال له أن يفتحه أوّلاً.
GeoPoint? parseGeoLink(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  // **الترتيب مقصود، وقِيس على روابط حقيقيّة لا على الظنّ.**
  //
  // رابطُ «مكان» في خرائط Google يحمل نقطتين مختلفتين:
  //
  //   * `@15.30,44.10,17z` — مركزُ **الكاميرا**، أي أين كانت الشاشة حين نُسخ
  //     الرابط. وقد يبعد عن المكان مئات الأمتار إن كان المستخدم قد حرّك
  //     الخريطة قبل النسخ.
  //   * `…!3d15.354722!4d44.206667` — **دبّوسُ المكان نفسه**.
  //
  // فالدبّوسُ أوّلاً. وأوّلُ ما كُتب هنا لم يعرفه أصلاً، فكان يُرجع مركزَ
  // الكاميرا حين يجتمعان، **ويُرجع `null` لرابطٍ صحيحٍ لا `@` فيه** — وهي
  // صيغةٌ تخرج من زرّ «مشاركة» في التطبيق. قِيس الاثنان فظهر الخطأ.
  final patterns = <RegExp>[
    RegExp(r'!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)'),
    RegExp(r'@(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    RegExp(r'[?&](?:q|ll|daddr|destination)=(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    RegExp(r'geo:(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    // اللصقُ المجرّد آخراً: أوسعُها، فلا يُسأل عنه إلّا بعد أن تخيب الأدقّ.
    RegExp(r'^\s*(-?\d{1,3}\.\d+)\s*[,، ]\s*(-?\d{1,3}\.\d+)\s*$'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) continue;
    final point = GeoPoint(lat, lng);
    if (point.isValid) return point;
  }
  return null;
}

/// رابطٌ يفتح النقطةَ في تطبيق الخرائط على الجهاز.
///
/// **وعنوانُ الويب لا `geo:`** — و`geo:` هو الأصحّ نظريّاً: يفتح أيَّ تطبيق
/// خرائطٍ مثبَّت. لكنّه لا يُفتح على iOS أصلاً، ولا يُفتح على جهاز أندرويد
/// ليس فيه تطبيق خرائط — وهو حالُ أجهزةٍ كثيرةٍ هنا تأتي بلا خدمات Google.
/// وعنوانُ الويب يفتح التطبيقَ إن وُجد والمتصفّحَ إن لم يوجد، فلا يقف صاحبُه
/// أمام زرٍّ لا يفعل شيئاً ليلةَ العرس.
String mapsUrl(GeoPoint point) =>
    'https://www.google.com/maps/search/?api=1&query=$point';

/// مركزُ المحافظة تقريباً — تُفتح عليه الخريطةُ لمن لم يحدّد بعد.
///
/// **وليست دقّةً بل بدايةً:** من يفتح خريطةً على وسط المحيط يمضي دقيقةً
/// يبحث عن بلده قبل أن يبدأ. وعواصمُ المحافظات معلومةٌ جغرافيّاً ولا تحتاج
/// خدمةَ ترميزٍ ولا مفتاحاً.
const Map<String, GeoPoint> governorateCenters = {
  'أمانة العاصمة': GeoPoint(15.3694, 44.1910),
  'صنعاء': GeoPoint(15.3694, 44.1910),
  'عدن': GeoPoint(12.7855, 45.0187),
  'تعز': GeoPoint(13.5789, 44.0178),
  'الحديدة': GeoPoint(14.7978, 42.9545),
  'حضرموت': GeoPoint(15.9300, 48.7900),
  'إب': GeoPoint(13.9667, 44.1833),
  'ذمار': GeoPoint(14.5426, 44.4014),
  'المكلا': GeoPoint(14.5425, 49.1242),
  'صعدة': GeoPoint(16.9402, 43.7637),
  'حجة': GeoPoint(15.6943, 43.6047),
  'مأرب': GeoPoint(15.4625, 45.3256),
  'لحج': GeoPoint(13.0577, 44.8819),
  'أبين': GeoPoint(13.6300, 45.3700),
  'شبوة': GeoPoint(14.5333, 46.8333),
  'المهرة': GeoPoint(16.5333, 52.1833),
  'الضالع': GeoPoint(13.6957, 44.7314),
  'ريمة': GeoPoint(14.6278, 43.4736),
  'المحويت': GeoPoint(15.4700, 43.5450),
  'عمران': GeoPoint(15.6594, 43.9439),
  'الجوف': GeoPoint(16.7900, 44.7500),
  'البيضاء': GeoPoint(13.9892, 45.5744),
  'سقطرى': GeoPoint(12.6333, 53.9167),
};

/// نقطةُ البدء: نقطتُه إن كانت، وإلّا مركزُ محافظته، وإلّا صنعاء.
GeoPoint startingPoint({GeoPoint? saved, String governorate = ''}) =>
    saved ??
    governorateCenters[governorate.trim()] ??
    const GeoPoint(15.3694, 44.1910);

/// يقرأ نقطةً من صفٍّ جاء من القاعدة، أو `null` إن نقص أحدُ العمودين.
///
/// **ونصفُ نقطةٍ ليست نقطة.** القاعدةُ تمنع ذلك بقيد، لكنّ الصفَّ قد يصل من
/// طريقةٍ لا تحمل العمودين أصلاً — فيُقرأ الغيابُ غياباً لا صفراً.
GeoPoint? pointFromRow(Map<String, dynamic> m, String latKey, String lngKey) {
  final lat = (m[latKey] as num?)?.toDouble();
  final lng = (m[lngKey] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  final p = GeoPoint(lat, lng);
  return p.isValid ? p : null;
}

/// المسافةُ بالكيلومترات بين نقطتين — القانونُ الهافرسينيّ.
///
/// **وهي نسخةُ `public.distance_km` نفسها في القاعدة**، بنصف القطر نفسه
/// (٦٣٧١ كم). فالخادمُ يرتّب بها، والتطبيقُ يعرض بها الرقمَ على البطاقة —
/// ولو اختلف الحسابان لَقال الترتيبُ شيئاً وقالت البطاقةُ غيره.
///
/// وتُحسب هنا لا تُطلب من الخادم: العمودان في الصفّ أصلاً، فضربٌ واحدٌ لكلّ
/// بطاقةٍ معروضة أرخصُ من عمودٍ محسوبٍ يُنقل في كلّ صفّ.
double distanceKm(GeoPoint a, GeoPoint b) {
  const radius = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final h = math.pow(math.sin(rad(b.lat - a.lat) / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(rad(b.lng - a.lng) / 2), 2);
  return 2 * radius * math.asin(math.sqrt(h));
}

/// يرتّب قائمةً بالقرب من [from] — ومن لا نقطةَ له في الذيل لا خارجَ القائمة.
///
/// **وهي للوضع التجريبيّ وحده.** حين تكون القاعدةُ موصولةً يقع الترتيبُ في
/// الخادم: القائمةُ محدودةٌ بأربعين صفّاً، وترتيبُ صفحةٍ جاءت مرتّبةً بالتمييز
/// يعطي «أقربَ الأربعين» لا «الأقربَ فعلاً» — وهما مختلفان حين يكون في
/// المنصّة ألف.
///
/// ويُطابق ترتيبُها ترتيبَ `nulls last` في الخادم، فلا تختلف الشاشةُ بين
/// وضعين.
void sortByDistance<T>(
  List<T> items,
  GeoPoint from,
  GeoPoint? Function(T) pointOf,
) {
  items.sort((a, b) {
    final pa = pointOf(a);
    final pb = pointOf(b);
    if (pa == null && pb == null) return 0;
    if (pa == null) return 1; // من لا نقطةَ له آخراً
    if (pb == null) return -1;
    return distanceKm(from, pa).compareTo(distanceKm(from, pb));
  });
}

/// «٤ كم» أو «٧٥٠ م» — نصٌّ يُقرأ لا رقمٌ عشريّ بأربع خانات.
///
/// **ودون الكيلومتر تُقال بالأمتار:** «٠٫٤ كم» تُقرأ بجهد، و«٤٠٠ م» تُعرف
/// بنظرة. وفوق ذلك خانةٌ واحدة، وفوق العشرة لا كسورَ أصلاً — من يختار بين
/// قاعتين لا يعنيه المئةُ متر.
String distanceLabel(double km) {
  if (km < 1) return '${(km * 1000).round()} م';
  if (km < 10) return '${km.toStringAsFixed(1)} كم';
  return '${km.round()} كم';
}
