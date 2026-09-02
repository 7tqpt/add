// «صدرت نسخةٌ أحدث» — شريطٌ يُطوى، أو شاشةٌ لا تُطوى.
//
// ── ولماذا وجهان لا واحد ────────────────────────────────────────────────────
//
// **التحديثُ العاديُّ خبرٌ، والإجباريُّ بابٌ مقفل.** ونافذةٌ تُغلق بـ«لاحقاً»
// تكفي الأوّل: من كان في وسط حجزٍ لا يُقطع عليه ليُقال له إنّ نسخةً صدرت.
// أمّا الإجباريُّ فأُشعل لأنّ ما قبله لا يصلح — نداءٌ يفشل، أو حسابٌ يُكشف —
// وشريطٌ يُطوى لا يمنع أحداً من الاستمرار على المكسور.
//
// **وشريطٌ في أعلى الشاشة لا نافذةٌ تقفز.** النافذةُ تقع على من فتح تطبيقه
// ليردّ على رسالة، فيُغلقها بلا قراءة. والشريطُ يبقى حتى يُنظر إليه، ولا
// يقطع أحداً عن عمله.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_update.dart';
import '../core/app_version.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../ui/kit.dart';

/// بديلٌ يُركَّب في الاختبارات بدل نداء الشبكة.
Future<List<AppRelease>> Function()? releasesOverride;

/// بديلُ حصّة الجهاز — لتُقاس حالاتُ الطرح التدريجيّ بلا عشوائيّة.
int? updateBucketOverride;

/// النسخةُ الواحدة — كما `appLock`.
final appUpdate = UpdateGate();

/// يعرف: أيُمنع الاستعمال؟ وهل ثمّ نسخةٌ تُعرض؟
///
/// **ولا يُسقط شيئاً أبداً.** فحصُ التحديث خدمةٌ زائدة، وتطبيقٌ لا يُقلع
/// لأنّ فحصَ نسخةٍ فشل عطبٌ أكبرُ من الذي يتجنّبه. فكلُّ نداءٍ محروس،
/// وغيابُ الجواب يعني «لا شيء يُعرض».
class UpdateGate extends ChangeNotifier {
  AppRelease? _forced;
  AppRelease? _banner;
  bool _dismissed = false;

  /// النسخةُ التي تمنع الاستعمالَ حتى تُنزَّل، إن وُجدت.
  AppRelease? get forced => _forced;

  /// النسخةُ التي تُعرض في الشريط — تختفي بـ«لاحقاً».
  AppRelease? get banner => _dismissed ? null : _banner;

  Future<void> check() async {
    try {
      final releases = await (releasesOverride ?? Api.releases)();
      if (releases.isEmpty) return;
      final bucket = updateBucketOverride ?? await updateBucket();
      final pick = pickUpdate(
        releases,
        installedBuild: appBuild,
        bucket: bucket,
      );
      // **ولا منعَ بلا مخرج.** شاشةٌ تقول «لا بدّ من التحديث» وزرُّها لا يفتح
      // شيئاً تحبس صاحبَ الجهاز — وهو أذىً أكبرُ من نسخةٍ قديمة.
      //
      // وهذا مضمونٌ **ببنية الشيفرة لا بشرطٍ يُفحص**: `_forced` لا تكون إلّا
      // `pick`، و`pick` لا تخرج من `pickUpdate` إلّا وقد مرّت على
      // `safeDownloadUrl`. فمن رأى الشاشةَ رأى معها زرّاً يعمل.
      //
      // وقد كتبتُ هنا أوّلاً `&& pick != null` فبدا حارساً، وهو شرطٌ ميّت:
      // `blocked ? pick : null` تُعطي `null` إن كانت `pick` كذلك على كلّ حال.
      // كشفه ضابطٌ سالبٌ لم يسقط.
      if (pick == null) return;
      final blocked = mustUpdate(releases, installedBuild: appBuild);
      _forced = blocked ? pick : null;
      _banner = blocked ? null : pick;
      notifyListeners();
    } catch (_) {
      // لا شيء يُعرض، والتطبيق يعمل.
    }
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }
}

/// يفتح رابطَ التنزيل في متصفّح الجهاز.
///
/// **وفي متصفّحٍ خارجيٍّ لا داخل التطبيق:** حزمةُ APK لا تُثبَّت من عارضٍ
/// مدمَج — أندرويد يسلّم التثبيت إلى المتصفّح ومنه إلى مثبّت النظام.
Future<void> openDownload(BuildContext context, String url) async {
  if (!safeDownloadUrl(url)) {
    showMessage(context, tr('رابط التنزيل غير صالح — راجع الإدارة.'));
    return;
  }
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showMessage(context, trf('تعذّر فتح الرابط — افتح {0} في متصفّحك.', [url]));
  }
}

/// شريطُ «صدرت نسخةٌ أحدث» — يُطوى بـ«لاحقاً».
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.release,
    required this.onDismiss,
  });

  final AppRelease release;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
        child: Row(
          children: [
            const Icon(Icons.system_update, size: 20, color: AppColors.accent),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trf('صدرت نسخة {0}', [release.version]),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (release.notes.trim().isNotEmpty)
                    Muted(release.notes.trim(), size: 11, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            TextButton(
              key: const ValueKey('update-download'),
              onPressed: () => openDownload(context, release.downloadUrl),
              child: Text(tr('نزّلها')),
            ),
            IconButton(
              key: const ValueKey('update-dismiss'),
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18, color: AppColors.ink2),
              tooltip: tr('لاحقاً'),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشةُ التحديث الإجباريّ — لا مخرجَ منها إلّا التحديث.
///
/// **ولا زرَّ «لاحقاً» فيها عمداً.** ومن أراد أن يستعمل نسخته القديمة يغلق
/// التطبيق — ولا نُوهمه بأنّ له خياراً هنا وليس له.
class ForcedUpdateScreen extends StatelessWidget {
  const ForcedUpdateScreen({super.key, required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update,
                    size: 44, color: AppColors.accent),
                const SizedBox(height: Space.lg),
                Text(
                  tr('لا بدّ من التحديث'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  trf('نسختُك لم تعد تعمل مع الخدمة. نزّل نسخة {0} لتُكمل.',
                      [release.version]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted, height: 1.8),
                ),
                if (release.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  AppCard(
                    children: [
                      Text(release.notes.trim(),
                          style: const TextStyle(fontSize: 12, height: 1.8)),
                    ],
                  ),
                ],
                const SizedBox(height: Space.xl),
                FilledButton(
                  key: const ValueKey('forced-download'),
                  onPressed: () => openDownload(context, release.downloadUrl),
                  child: Text(tr('نزّل التحديث')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
