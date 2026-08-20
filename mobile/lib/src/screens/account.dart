import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import 'become_provider.dart';
import 'support.dart';

/// بطاقةُ قسمٍ في صفحة الحساب.
///
/// الأقسام الثلاثة بنيةٌ واحدة: قرصٌ ملوّن بأيقونته، وعنوان، وسطرُ شرح، ثم
/// الإجراء. وكانت البطاقات تتفاوت — واحدةٌ بقرصٍ واثنتان بلا — فتُقرأ الصفحة
/// قائمةً مبعثرة لا صفّاً منظّماً. والتفاوت هنا لا يحمل معنىً، فالتوحيد لا
/// يُضيّع شيئاً.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: SectionTitle(title)),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(body, style: const TextStyle(height: 1.7, color: AppColors.ink2)),
        const SizedBox(height: Space.md),
        action,
      ],
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final provider = session.hasProviderProfile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, glassNavSpace),
      children: [
        // ── الهويّة ────────────────────────────────────────────────────────
        // بطاقةٌ تقول من أنت قبل ما تستطيع فعله. وكانت سطراً واحداً باهتاً
        // («حسابي» ثم البريد)، وهي أوّل ما تقع عليه العين في الصفحة.
        AppCard(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initial(session.email),
                    // النمط كاملٌ مكتوبٌ باليد، فيُذكر الخطّ صراحةً: النمط
                    // الكامل يحلّ محلّ الموروث ولا يرث احتياط الثيمة.
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentInk,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // البريد لاتينيٌّ دائماً، والصفحة عربية: بلا اتجاهٍ
                      // صريح تتقدّم النقطةُ والامتدادُ إلى غير موضعهما.
                      Text(
                        session.email,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          fontFamilyFallback: arabicFallback,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      StatusBadge(
                        provider ? 'عميل ومقدّم خدمة' : 'عميل',
                        color: provider ? AppColors.good : AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: Space.md),

        // ── مقدّم الخدمة ───────────────────────────────────────────────────
        // مقدَّمٌ على الدعم عمداً: هذا طريقُ من يريد أن يكسب من المنصة،
        // والدعم بابٌ يُطرق عند العطل لا كل يوم.
        //
        // وكل من يسجّل يبدأ عميلاً — والمنصة تُباع للعملاء أوّلاً. ومن أراد
        // أن يبيع خدمةً طلبها من هنا، فيصير له ملفٌّ قيد المراجعة.
        _SectionCard(
          icon: provider ? Icons.storefront : Icons.add_business_outlined,
          tone: provider ? AppColors.good : AppColors.accent,
          title: 'مقدّم خدمة',
          body: provider
              ? 'لديك ملف مقدّم خدمة. بدّل الوضع لإدارة خدماتك وطلباتك وحجوزاتك.'
              : 'عندك قاعة أو خدمة تقدّمها للأعراس؟ قدّم طلبك، وبعد مراجعة الإدارة '
                    'تبدأ باستقبال الحجوزات.',
          action: provider
              ? FilledButton.icon(
                  onPressed: () => session.switchTo(provider: true),
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('التبديل إلى وضع مقدّم الخدمة'),
                )
              : OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BecomeProviderScreen(session: session),
                    ),
                  ),
                  icon: const Icon(Icons.add_business_outlined, size: 20),
                  label: const Text('أريد تقديم خدمة'),
                ),
        ),

        const SizedBox(height: Space.md),

        // ── الدعم ──────────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.support_agent,
          tone: AppColors.accent,
          title: 'الدعم',
          body: 'واجهتك مشكلة أو عندك سؤال؟ افتح تذكرة وتصلك ردود الإدارة هنا.',
          action: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SupportScreen(session: session)),
            ),
            icon: const Icon(Icons.support_agent, size: 20),
            label: const Text('تذاكر الدعم'),
          ),
        ),

        const SizedBox(height: Space.md),

        // ── الخروج ─────────────────────────────────────────────────────────
        // بطاقةٌ كالبقية لا زرٌّ عائمٌ في آخر الصفحة، وبصبغة التحذير: هو
        // الإجراء الوحيد هنا الذي يُخرجك، فيُعرَف قبل أن يُضغط. ويُسأل عنه
        // لأن ضغطةً واحدة بالخطأ تُخرج المستخدم ثم تطلب منه بريده وكلمته.
        _SectionCard(
          icon: Icons.logout,
          tone: AppColors.critical,
          title: 'تسجيل الخروج',
          body: 'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
          action: OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.critical,
              side: const BorderSide(color: AppColors.critical),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('تسجيل الخروج'),
          ),
        ),

        const SizedBox(height: Space.xl),
        const Center(child: Muted('الإصدار 1.0.0', size: 11)),
        const SizedBox(height: Space.lg),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
          'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (yes == true) session.signOut();
  }

  /// أوّل حرفٍ من البريد للقرص. والبريد لا يكون فارغاً هنا — الصفحة لا تُعرض
  /// إلا بعد الدخول — لكن الاحتياط أرخص من مربّعٍ فارغ في وجه المستخدم.
  static String _initial(String email) {
    final clean = email.trim();
    if (clean.isEmpty) return '؟';
    return clean.characters.first.toUpperCase();
  }
}
