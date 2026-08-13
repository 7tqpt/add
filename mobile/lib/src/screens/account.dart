import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import 'become_provider.dart';
import 'support.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppCard(children: [const SectionTitle('حسابي'), KeyValue('البريد', session.email)]),
        const SizedBox(height: Space.md),
        AppCard(
          children: [
            const SectionTitle('الدعم'),
            const SizedBox(height: Space.sm),
            const Text(
              'واجهتك مشكلة أو عندك سؤال؟ افتح تذكرة وتصلك ردود الإدارة هنا.',
              style: TextStyle(height: 1.7),
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => SupportScreen(session: session))),
              icon: const Icon(Icons.support_agent, size: 20),
              label: const Text('تذاكر الدعم'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        /*
         * مدخل مقدّم الخدمة.
         *
         * كل من يسجّل يبدأ عميلاً — وهذا هو المطلوب: المنصة تُباع للعملاء أولاً.
         * ومن أراد أن يبيع خدمة يطلبها من هنا، فيصير له ملفٌ قيد المراجعة
         * وأيقونةُ تبديلٍ بين الوضعين.
         */
        AppCard(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: Space.md),
                const Expanded(child: SectionTitle('مقدّم خدمة')),
              ],
            ),
            const SizedBox(height: Space.md),
            if (session.hasProviderProfile) ...[
              const Text(
                'لديك ملف مقدّم خدمة. بدّل الوضع لإدارة طلباتك.',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: () => session.switchTo(provider: true),
                icon: const Icon(Icons.swap_horiz, size: 20),
                label: const Text('التبديل إلى وضع مقدّم الخدمة'),
              ),
            ] else ...[
              const Text(
                'عندك قاعة أو خدمة تقدّمها للأعراس؟ قدّم طلبك، وبعد مراجعة الإدارة تبدأ باستقبال الحجوزات.',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => BecomeProviderScreen(session: session))),
                icon: const Icon(Icons.add_business_outlined, size: 20),
                label: const Text('أريد تقديم خدمة'),
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.xl),
        TextButton(onPressed: () => session.signOut(), child: const Text('تسجيل الخروج')),
        const SizedBox(height: Space.sm),
        const Center(child: Muted('الإصدار 0.1.0', size: 11)),
      ],
    );
  }
}
