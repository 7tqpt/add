// البحثُ عن مكانٍ باسمه — «حدة»، «جامع الصالح»، «شارع الزبيري».
//
// **وهذا ما كان ينقص الخريطةَ أكثرَ من غيره.** من يعرف اسمَ الحيّ ولا يعرف
// شكلَه من فوق يبقى يحرّك خريطةً بيضاءَ بإصبعه حتى يملّ.
//
// ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
//
// **١) الخدمةُ Nominatim من OpenStreetMap.** بلا مفتاحٍ وبلا فوترة، كالبلاطات.
// وشرطُها الذي يُلتزم به هنا: ترويسةُ `User-Agent` تعرّف التطبيق بنفسه —
// ومن أهملها حُجب.
//
// **٢) ولا بحثَ مع كلّ حرف.** سياسةُ Nominatim تمنع الإكمالَ التلقائيّ صراحةً
// (طلبٌ واحدٌ في الثانية على الأكثر)، ويُبحث عند الإرسال وحده. وهذا موافقٌ
// لما في التطبيق أصلاً: شبكةُ الجوال هنا ليست سخيّة، وكلُّ ضغطةِ حرفٍ طلب.
//
// **٣) واليمنُ وحدها.** `countrycodes=ye` — فمن كتب «الحديدة» يريد الحديدة
// اليمنيّة لا بلدةً تشبه اسمَها في المغرب. وهذا يقصّ النتائج إلى ما ينفع.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geo.dart';

/// مكانٌ وُجد بالبحث.
class Place {
  const Place({required this.name, required this.point});

  /// الاسمُ كما تعيده الخدمة — يُعرض في القائمة ليختار صاحبُه.
  final String name;
  final GeoPoint point;
}

/// بديلٌ يُركَّب في الاختبارات — لا شبكةَ في `flutter test`.
Future<List<Place>> Function(String query)? placeSearchOverride;

/// يبحث عن مكانٍ باسمه في اليمن، أو يرمي نصّاً عربيّاً يُعرض كما هو.
///
/// **ويرمي ولا يعيد قائمةً فارغةً عند العطل:** «لا نتائج» و«لا شبكة» حالتان
/// مختلفتان، وعلاجُ الثانية إعادةُ المحاولة. ومن قيل له «لا نتائج» وهو مقطوعٌ
/// عن الشبكة يظنّ مكانَه غيرَ موجودٍ فيكفّ عن البحث.
Future<List<Place>> searchPlaces(String query) async {
  final override = placeSearchOverride;
  if (override != null) return override(query);

  final term = query.trim();
  if (term.isEmpty) return const [];

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': term,
    'format': 'jsonv2',
    'limit': '6',
    // العربيّةُ أوّلاً — ومن يبحث هنا يقرأ العربيّة.
    'accept-language': 'ar',
    'countrycodes': 'ye',
  });

  final http.Response response;
  try {
    response = await http
        .get(uri, headers: const {
          // شرطُ سياسة Nominatim: يُعرَّف الطالبُ بنفسه. ومن أهملها حُجب.
          'User-Agent': 'Farhati/1.0 (company.sdd.farhati)',
        })
        .timeout(const Duration(seconds: 12));
  } catch (_) {
    throw 'تعذّر الوصول إلى خدمة البحث. تحقّق من الشبكة وأعد المحاولة.';
  }

  if (response.statusCode != 200) {
    throw 'خدمة البحث لا تستجيب الآن (${response.statusCode}). '
        'حرّك الخريطة بإصبعك أو الصق رابطاً.';
  }

  final List<dynamic> rows;
  try {
    // **وبايتاتٌ تُفكّ بـUTF-8 صراحةً.** `response.body` يقرأ بـLatin-1 حين
    // لا تذكر الترويسةُ الترميز، فتصير أسماءُ الأحياء العربيّة رموزاً.
    rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  } catch (_) {
    throw 'جاء من خدمة البحث ردٌّ لم أفهمه.';
  }

  final places = <Place>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final lat = double.tryParse('${row['lat']}');
    final lng = double.tryParse('${row['lon']}');
    final name = '${row['display_name'] ?? ''}'.trim();
    if (lat == null || lng == null || name.isEmpty) continue;
    final point = GeoPoint(lat, lng);
    if (!point.isValid) continue;
    places.add(Place(name: name, point: point));
  }
  return places;
}

/// يختصر اسماً طويلاً إلى أوّل ثلاثة أجزاء.
///
/// **ولماذا:** Nominatim يعيد العنوانَ كاملاً — «السنينة، مديرية معين، أمانة
/// العاصمة، اليمن» — وأربعةُ أسطرٍ لكلّ نتيجةٍ تجعل القائمةَ صفحةً تُمرَّر.
/// والثلاثةُ الأولى هي التي تُميّز.
String shortPlaceName(String full) {
  final parts = full.split('،').map((p) => p.trim()).where((p) => p.isNotEmpty);
  return parts.take(3).join('، ');
}
