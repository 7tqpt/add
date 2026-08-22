import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/service_card.dart';
import 'chat.dart';
import 'service_detail.dart';

/// ملفُّ مقدّم الخدمة كما يراه العميل.
///
/// **لماذا:** الخدمة تُعرض وحدها فيُحكَم عليها وحدها. ومن رأى «كوشة ورد» لا
/// يعرف أنّ صاحبها يعرض تنسيق المداخل والطاولات أيضاً، ولا كم عرساً نفّذ، ولا
/// ماذا قال من تعامل معه. فيقارن ثمناً بثمن، وهو لا يشتري ثمناً بل يشتري من
/// يُسلّمه ليلةً لا تُعاد.
///
/// وغير `ProviderProfileScreen`: تلك شاشةُ المزوّد عن نفسه — يعدّل ملفَّه
/// ويرى حالة توثيقه. وهذه صفحتُه عند غيره: لا تعديلَ فيها ولا حالة، وليس
/// فيها بريدٌ ولا رقمُ جوال. الاتصال بها يقع في المحادثة داخل المنصّة، فيبقى
/// للكلام سجلٌّ إن وقع نزاع.
class PublicProviderScreen extends StatefulWidget {
  const PublicProviderScreen({super.key, required this.providerId, this.name});

  final String providerId;

  /// الاسمُ إن كان معروفاً قبل الفتح — يُكتب في الشريط ريثما يصل الملفّ، فلا
  /// تُفتح الشاشة على عنوانٍ عامّ ثم يتبدّل.
  final String? name;

  @override
  State<PublicProviderScreen> createState() => _PublicProviderScreenState();
}

class _PublicProviderScreenState extends State<PublicProviderScreen> {
  late Future<PublicProvider?> _future;
  late Future<List<ServiceItem>> _services;
  late Future<List<Review>> _reviews;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // ثلاثةٌ متوازية لا متتابعة: شبكةُ الجوال هنا ليست سخيّة، وتتابعُها يجمع
    // زمنها كلَّه بلا سبب.
    _future = Api.provider(widget.providerId);
    _services = Api.providerServices(widget.providerId);
    _reviews = Api.providerReviews(widget.providerId);
  }

  void _reload() {
    setState(_load);
  }

  Future<void> _message(PublicProvider p) async {
    setState(() => _busy = true);
    try {
      final id = await Api.openConversation(p.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: p.businessName,
            mySide: ChatSide.customer,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name ?? 'مقدّم الخدمة')),
      body: FutureBuilder<PublicProvider?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final p = snap.data;
          // غيرُ الموثَّق لا يُفتح ملفُّه: سياسةُ القراءة تُخفيه فتعود القراءة
          // فارغة. والرسالة تقول ما وقع بلا أن تقول عن أحدٍ إنه مرفوض.
          if (p == null) {
            return const EmptyBlock(
              title: 'الملفّ غير متاح',
              description: 'قد يكون مقدّم الخدمة قد أوقف عرضه أو لم تُوثّقه الإدارة بعد.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              _Head(provider: p),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: _busy ? null : () => _message(p),
                icon: const Icon(Icons.forum_outlined, size: 19),
                label: Text('راسل ${p.businessName}'),
              ),
              const SizedBox(height: Space.lg),
              const SectionTitle('الخدمات المعروضة'),
              const SizedBox(height: Space.sm),
              _Services(future: _services, onRetry: _reload),
              const SizedBox(height: Space.lg),
              _Reviews(future: _reviews, total: p.reviewsCount),
              const SizedBox(height: Space.xl),
            ],
          );
        },
      ),
    );
  }
}

/// ترويسةُ الملفّ: الاسم وعلاماتُه، ثم ثلاثةُ أرقام، ثم التعريف والأقسام.
class _Head extends StatelessWidget {
  const _Head({required this.provider});
  final PublicProvider provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return AppCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حرفٌ في قرصٍ بدل صورةٍ لا وجود لها: الجدول لا يحمل شعاراً، وإطارٌ
            // رماديّ فارغ يقول إن شيئاً لم يُحمَّل — وليس هناك ما يُحمَّل.
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: Tint.disc),
              ),
              child: Text(
                p.businessName.isEmpty ? '؟' : p.businessName.characters.first,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(p.businessName),
                  const SizedBox(height: Space.xs),
                  if (p.governorate.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Flexible(child: Muted(p.governorate)),
                      ],
                    ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      // «موثَّق» أوّلاً: هي العلامة التي تعني أن الإدارة رأت
                      // مستنداته، و«مميّز» ترتيبٌ اشتراه — فلا تُقدَّم عليها.
                      if (p.isVerified) const StatusBadge('موثَّق', color: AppColors.good),
                      if (p.isFeatured) const StatusBadge('مميّز', color: AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            _Stat(
              value: p.rating > 0 ? '${p.rating}' : '—',
              label: p.reviewsCount > 0
                  ? 'من ${formatCount(p.reviewsCount, reviewForms)}'
                  : 'لا تقييم بعد',
              icon: Icons.star_rounded,
              tone: AppColors.warning,
            ),
            _Stat(
              value: '${p.completedBookings}',
              label: 'حجزاً منفَّذاً',
              icon: Icons.verified_outlined,
              tone: AppColors.good,
            ),
          ],
        ),
        if (p.bio.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text(p.bio, style: const TextStyle(height: 1.8)),
        ],
        if (p.categories.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [for (final c in p.categories) _Tag(c)],
          ),
        ],
        // مناطقُ التغطية تُذكر إن زادت على محافظته: «يخدم تعز» لمن هو في تعز
        // خبرٌ لا يفيد، وذكرُها لمن هو في إبّ هو الفرق بين أن يحجز ولا يحجز.
        if (p.coverageAreas.where((a) => a != p.governorate).isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Muted(
            'يخدم أيضاً: ${p.coverageAreas.where((a) => a != p.governorate).join(' · ')}',
            size: 11,
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon, required this.tone});
  final String value;
  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 20, color: tone),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Muted(label, size: 11),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: Tint.chip),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600),
    ),
  );
}

class _Services extends StatelessWidget {
  const _Services({required this.future, required this.onRetry});
  final Future<List<ServiceItem>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceItem>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(Space.lg), child: LoadingBlock());
        }
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: onRetry);
        }
        final rows = snap.data ?? const <ServiceItem>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا خدمات معروضة الآن',
            description: 'راسله لتسأل عمّا يقدّمه.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in rows) ...[
              ServiceListCard(
                item: item,
                // اسمُ المزوّد لا يُكرَّر في صفحته: القارئ فيها يعرف عند من هو.
                showProvider: false,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id)),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
          ],
        );
      },
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.future, required this.total});
  final Future<List<Review>> future;
  final int total;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Review>[];
        // لا كتلةَ خطأ هنا: التقييمات مكمّلة، وعطبُ قراءتها لا يجوز أن يُفسد
        // صفحةً بقيّتُها سليمة. تغيب بصمتٍ ويبقى ما فوقها.
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('آراء العملاء')),
                if (total > rows.length) Muted('من $total'),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final r in rows) ...[
              AppCard(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.userName.isEmpty ? 'عميل' : r.userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Rating(r.rating),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Text(r.comment, style: const TextStyle(height: 1.7, fontSize: 13.5)),
                  ],
                  const SizedBox(height: Space.xs),
                  Muted(formatDate(r.createdAt), size: 11),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      },
    );
  }
}
