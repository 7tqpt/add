import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'service_detail.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String _applied = '';
  String? _categoryId;
  late Future<List<ServiceCategory>> _categories;
  late Future<List<ServiceItem>> _services;

  @override
  void initState() {
    super.initState();
    _categories = Api.categories();
    _reload();
  }

  void _reload() {
    setState(() {
      _services = Api.services(search: _applied, categoryId: _categoryId);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            // البحث عند الإرسال لا عند كل حرف: كل ضغطة طلبٌ للشبكة، وشبكة
            // الجوال هنا ليست دائماً سخيّة.
            onSubmitted: (v) {
              _applied = v;
              _reload();
            },
            decoration: const InputDecoration(
              hintText: 'ابحث عن قاعة، مصوّر، طبّاخ…',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: FutureBuilder<List<ServiceCategory>>(
            future: _categories,
            builder: (context, snap) {
              final cats = snap.data ?? const <ServiceCategory>[];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                children: [
                  PickChip(
                    label: 'الكل',
                    active: _categoryId == null,
                    onTap: () {
                      _categoryId = null;
                      _reload();
                    },
                  ),
                  for (final c in cats) ...[
                    const SizedBox(width: Space.sm),
                    PickChip(
                      label: c.name,
                      active: _categoryId == c.id,
                      onTap: () {
                        _categoryId = c.id;
                        _reload();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ServiceItem>>(
            future: _services,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
              if (snap.hasError) {
                return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
              }
              final items = snap.data ?? const <ServiceItem>[];
              if (items.isEmpty) {
                return const EmptyBlock(
                  title: 'لا توجد خدمات مطابقة',
                  description: 'جرّب قسماً آخر أو امسح البحث.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(Space.lg),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                itemBuilder: (context, i) => _ServiceCard(item: items[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final ServiceItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id))),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (item.providerIsFeatured) ...[
              const SizedBox(width: Space.sm),
              const StatusBadge('مميّز', color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: Space.xs),
        Muted('${item.providerName} · ${item.categoryName} · ${item.providerGovernorate}'),
        const SizedBox(height: Space.sm),
        // النطاق السعري يطول: «850,000 ر.ي – 1,200,000 ر.ي» وحده يتجاوز عرض
        // الشاشة الضيّقة، فبلا Expanded يفيض الصفّ ويختفي التقييم خلف الحافة.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.priceTo == null
                    ? formatMoney(item.price)
                    : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            if (item.providerRating > 0)
              Rating(item.providerRating, count: item.providerReviewsCount)
            else
              const Muted('جديد'),
          ],
        ),
        const SizedBox(height: Space.xs),
        Muted('العربون ${item.depositPercent}٪ · ${item.unit}', size: 11),
      ],
    );
  }
}
