// «صدرت نسخةٌ أحدث» — من الجدول إلى شاشة صاحب الجوال.
//
// ── ثلاثةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
//
// **١) والاختيارُ دالّةٌ خالصةٌ لا شيفرةٌ في شاشة.** أيُّ نسخةٍ تُعرض؟ فيها
// رقمُ البناء المثبَّت، ونسبةُ الطرح، وحصّةُ الجهاز، والإجباريّ — وأربعةُ
// شروطٍ متشابكةٍ داخل `build()` لا تُقاس إلّا برسم الشاشة كلِّها. وهنا تُقاس
// بجدولٍ من الحالات.
//
// **٢) وأحدثُ ما **أستحقّه** لا أحدثُ ما وُجد.** لو صدرت ٣ بطرحٍ ١٠٪ و٢
// بطرحٍ ١٠٠٪، ومن كان على ١ ليس في العشرة — فالصوابُ أن يُعرض عليه ٢، لا أن
// يُترك على ١ لأنّ الأحدثَ لا يشمله. ولهذا تُقرأ عدّةُ صفوفٍ لا صفٌّ واحد.
//
// **٣) وحصّةُ الجهاز تُثبَّت مرّةً وتُحفظ.** رقمٌ عشوائيٌّ يُولَّد في كلّ
// إقلاع يجعل الطرحَ التدريجيَّ عبثاً: يُعرض التحديثُ اليومَ ويختفي غداً
// ويعود بعده. فيُولَّد مرّةً ويبقى، فيكون «العشرةُ في المئة» عشرةً في المئة
// من الأجهزة ثابتةً لا رجّةً يوميّة.
library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// صفُّ نسخةٍ كما يأتي من `app_versions`.
class AppRelease {
  const AppRelease({
    required this.build,
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.rolloutPercent,
  });

  final int build;
  final String version;
  final String notes;
  final String downloadUrl;
  final bool forceUpdate;
  final int rolloutPercent;

  static AppRelease fromMap(Map<String, dynamic> row) => AppRelease(
    build: (row['build'] as num?)?.toInt() ?? 0,
    version: (row['version'] as String?) ?? '',
    notes: (row['notes'] as String?) ?? '',
    downloadUrl: (row['download_url'] as String?) ?? '',
    forceUpdate: row['force_update'] == true,
    rolloutPercent: (row['rollout_percent'] as num?)?.toInt() ?? 100,
  );
}

/// أيُعرض هذا الرابطُ أصلاً؟
///
/// **وحارسٌ ثانٍ في التطبيق مع القيد في القاعدة.** القيدُ يحمي قاعدةً شُغّل
/// عليها `app_download.sql`، وهذا يحمي التطبيقَ من قاعدةٍ لم يُشغَّل عليها
/// بعد — أو من صفٍّ كُتب قبل أن يُضاف القيد.
bool safeDownloadUrl(String url) {
  if (!url.startsWith('https://')) return false;
  return Uri.tryParse(url)?.host.isNotEmpty ?? false;
}

/// يختار النسخةَ التي تُعرض، أو `null` إن لم يكن ثمّ ما يُعرض.
///
/// [bucket] حصّةُ الجهاز: عددٌ من ٠ إلى ٩٩ ثابتٌ لهذا التثبيت.
AppRelease? pickUpdate(
  List<AppRelease> releases, {
  required int installedBuild,
  required int bucket,
}) {
  final eligible = releases
      .where((r) => r.build > installedBuild)
      .where((r) => safeDownloadUrl(r.downloadUrl))
      // **والإجباريُّ لا تحجبه نسبةُ الطرح.** من أُشعل عليه «إجباريّ» فلأنّ
      // ما قبله مكسورٌ أو غيرُ آمن — وطرحُه على عشرةٍ في المئة يترك تسعين
      // في المئة على المكسور، وهو نقضٌ لمعنى الكلمة.
      .where((r) => r.forceUpdate || bucket < r.rolloutPercent)
      .toList();
  if (eligible.isEmpty) return null;

  eligible.sort((a, b) => b.build.compareTo(a.build));
  return eligible.first;
}

/// أيُمنع الاستعمالُ حتى يُحدَّث؟
///
/// **وليس «أحدثُها إجباريّ» بل «أفي المتخطَّى إجباريّ».** من كان على ١
/// وصدرت ٢ إجباريّةً ثمّ ٣ عاديّة، فالإجباريّةُ في طريقه وإن لم تكن الأحدث —
/// وهي أُشعلت لأنّ ١ لا يصلح، وذلك لم يتغيّر.
bool mustUpdate(List<AppRelease> releases, {required int installedBuild}) =>
    releases.any((r) => r.build > installedBuild && r.forceUpdate);

const _bucketKey = 'update_bucket';

/// حصّةُ هذا الجهاز من الطرح التدريجيّ — تُولَّد مرّةً وتبقى.
///
/// وإن تعذّر التخزين رجع ٠: فيرى صاحبُه التحديثَ في أوّل دفعة. **والخطأُ
/// إلى إظهارٍ زائدٍ لا إلى إخفاء** — من أُخفي عنه التحديثُ لا يعلم أنّه
/// أُخفي، ومن عُرض عليه مبكّراً يتجاهله.
Future<int> updateBucket() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_bucketKey);
    if (saved != null && saved >= 0 && saved < 100) return saved;
    final fresh = Random().nextInt(100);
    await prefs.setInt(_bucketKey, fresh);
    return fresh;
  } catch (_) {
    return 0;
  }
}
