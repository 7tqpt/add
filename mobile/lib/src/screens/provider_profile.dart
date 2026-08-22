import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'documents.dart';
import 'labels.dart';
import 'support.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key, required this.session});
  final Session session;
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late Future<ProviderProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.providerProfile(widget.session.providerId ?? '');
  }

  void _approveInDemo() {
    Api.approveProviderInDemo();
    setState(() {
      _future = Api.providerProfile(widget.session.providerId ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderProfile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
        final p = snap.data;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            Space.lg, glassHeaderTop(context), Space.lg, Space.lg),
          children: [
            if (p != null) ...[
              AppCard(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SectionTitle(p.businessName.isEmpty ? p.fullName : p.businessName),
                      ),
                      const SizedBox(width: Space.sm),
                      StatusBadge(
                        providerStatusLabel(p.status),
                        color: providerStatusColor(p.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(p.governorate),
                  if (p.bio.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(p.bio, style: const TextStyle(height: 1.8)),
                  ],
                  if (p.status == 'pending') ...[
                    const SizedBox(height: Space.md),
                    const Text(
                      'طلبك قيد المراجعة. لن تستقبل حجوزات حتى تُقبل مستنداتك.',
                      style: TextStyle(color: AppColors.warning, fontSize: 13, height: 1.7),
                    ),
                    // بلا مسؤولٍ يوثّق من اللوحة يقف المجرِّب هنا ولا يرى شاشة
                    // الطلبات. الزرّ موسومٌ «تجريبي» ولا يظهر إطلاقاً حين تُمرَّر
                    // مفاتيح مشروع حقيقي — التوثيق حينها قرار الإدارة وحدها.
                    if (!isSupabaseConfigured) ...[
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: _approveInDemo,
                        child: const Text('(تجريبي) محاكاة قبول الإدارة'),
                      ),
                    ],
                  ],
                  if (p.status == 'rejected' && p.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(
                      p.rejectionReason,
                      style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
                    ),
                  ],
                  // الزرّ في البطاقة نفسها لا في آخر الشاشة: الجملة التي تطلب
                  // المستندات مكتوبةٌ فوقه مباشرة، فيقع الطريق حيث يُطلب.
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DocumentsScreen(session: widget.session)),
                    ),
                    icon: const Icon(Icons.badge_outlined, size: 20),
                    label: const Text('مستندات التوثيق'),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppCard(
                children: [
                  const SectionTitle('أرقامك'),
                  KeyValue('التقييم', p.rating > 0 ? '${p.rating}' : 'لا تقييم بعد'),
                  KeyValue('عدد التقييمات', formatNumber(p.reviewsCount)),
                  KeyValue('حجوزات منفّذة', formatNumber(p.completedBookings)),
                  KeyValue('إجمالي الأرباح', formatMoney(p.totalEarnings)),
                ],
              ),
            ] else
              const AppCard(
                children: [
                  SectionTitle('لا ملف مقدّم خدمة'),
                  SizedBox(height: Space.sm),
                  Text('لم تُقدّم طلباً بعد.'),
                ],
              ),
            const SizedBox(height: Space.md),
            AppCard(
              children: [
                const SectionTitle('الدعم'),
                const SizedBox(height: Space.sm),
                const Text(
                  'مشكلة في المستندات أو الحجوزات؟ افتح تذكرة وتصلك ردود الإدارة.',
                  style: TextStyle(height: 1.7),
                ),
                const SizedBox(height: Space.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => SupportScreen(session: widget.session))),
                  icon: const Icon(Icons.support_agent, size: 20),
                  label: const Text('تذاكر الدعم'),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => widget.session.switchTo(provider: false),
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: const Text('العودة إلى وضع العميل'),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => widget.session.signOut(),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }
}
