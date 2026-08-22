import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'service_media.dart';

/// خدمات مقدّم الخدمة.
///
/// بلا هذه الشاشة يقف المزوّد عند التوثيق: ملفٌّ موثَّق لا يبيع شيئاً، لأن ما
/// يظهر في الاستكشاف صفوفُ `provider_services` ولم يكن له سبيلٌ إلى إنشائها.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.session});
  final Session session;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<List<MyService>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MyService>> _load() {
    final id = widget.session.providerId;
    return id == null ? Future.value(const []) : Api.myServices(id);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit([MyService? service]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ServiceEditor(session: widget.session, service: service),
    );
    if (saved == true) _reload();
  }

  Future<void> _media(MyService service) async {
    final providerId = widget.session.providerId;
    if (providerId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceMediaScreen(
          providerId: providerId,
          serviceId: service.id,
          serviceTitle: service.title,
        ),
      ),
    );
  }

  Future<void> _toggle(MyService service) async {
    setState(() => _busyId = service.id);
    try {
      await Api.setServiceActive(service.id, !service.isActive);
      if (!mounted) return;
      showMessage(context, service.isActive ? 'أُوقفت الخدمة' : 'عادت الخدمة للعرض');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('خدمة جديدة'),
      ),
      body: FutureBuilder<List<MyService>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <MyService>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا خدمات بعد',
              description: 'أضف ما تقدّمه بسعره وعربونه، ليظهر للعملاء في الاستكشاف.',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final s = rows[i];
              return AppCard(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SectionTitle(s.title)),
                      const SizedBox(width: Space.sm),
                      // المعطَّلة تحمل شارتها: بلا علامةٍ ظاهرة يظنّ صاحبها أنها
                      // معروضة، ويسأل لماذا لا تصله طلبات.
                      StatusBadge(
                        s.isActive ? 'معروضة' : 'موقوفة',
                        color: s.isActive ? AppColors.good : AppColors.muted,
                      ),
                    ],
                  ),
                  if (s.description.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Muted(s.description),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    s.priceTo == null
                        ? '${formatMoney(s.price)} · ${s.unit}'
                        : '${formatMoney(s.price)} – ${formatMoney(s.priceTo!)} · ${s.unit}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted('العربون ${s.depositPercent}٪', size: 11),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busyId == null ? () => _edit(s) : null,
                          child: const Text('تعديل'),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busyId == null ? () => _toggle(s) : null,
                          child: Text(s.isActive ? 'إيقاف' : 'عرض'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  // الوسائط بزرٍّ بعرض البطاقة لا بأيقونةٍ في الزاوية: خدمةٌ
                  // بلا صورةٍ لا تُحجز، وهذا أوّل ما ينبغي أن يفعله من أضاف
                  // خدمةً للتوّ — فيُعطى مساحته لا يُدسّ.
                  FilledButton.tonalIcon(
                    onPressed: _busyId == null ? () => _media(s) : null,
                    icon: const Icon(Icons.perm_media_outlined, size: 19),
                    label: const Text('الصور والمقاطع'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// محرّر الخدمة — ورقةٌ سفلية للإضافة والتعديل معاً.
class _ServiceEditor extends StatefulWidget {
  const _ServiceEditor({required this.session, this.service});
  final Session session;
  final MyService? service;

  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  late final _title = TextEditingController(text: widget.service?.title ?? '');
  late final _description = TextEditingController(text: widget.service?.description ?? '');
  late final _price = TextEditingController(text: widget.service?.price.toString() ?? '');
  late final _priceTo = TextEditingController(text: widget.service?.priceTo?.toString() ?? '');
  late final _unit = TextEditingController(text: widget.service?.unit ?? 'للحجز');
  late int _deposit = widget.service?.depositPercent ?? 30;
  late String? _categoryId = widget.service?.categoryId;

  late Future<List<ServiceCategory>> _categories;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categories = Api.categories();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _priceTo.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = num.tryParse(_price.text.trim());
    final priceTo = _priceTo.text.trim().isEmpty ? null : num.tryParse(_priceTo.text.trim());

    if (_title.text.trim().isEmpty || price == null || _categoryId == null) {
      setState(() => _error = 'اكتب اسم الخدمة وسعرها، واختر قسمها.');
      return;
    }
    // القاعدة تفرض `price_to >= price` بقيد، ورفضُها يصل نصّاً إنجليزياً غامضاً.
    // الشرط هنا يقوله بالعربية قبل أن يُرسَل.
    if (priceTo != null && priceTo < price) {
      setState(() => _error = 'أعلى السعر لا يكون أقلّ من أدناه.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.saveService(
        id: widget.service?.id,
        providerId: widget.session.providerId ?? '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId!,
        price: price,
        priceTo: priceTo,
        unit: _unit.text.trim().isEmpty ? 'للحجز' : _unit.text.trim(),
        depositPercent: _deposit,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ارتفاع لوحة المفاتيح يُضاف للحشو، وإلا غطّت الحقلَ الذي يكتب فيه.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(widget.service == null ? 'خدمة جديدة' : 'تعديل الخدمة'),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'اسم الخدمة',
                hintText: 'قاعة التاج — باقة شاملة',
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                hintText: 'ما الذي تشمله الباقة؟',
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'السعر (ر.ي)'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextField(
                    controller: _priceTo,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'إلى (اختياري)',
                      hintText: 'لنطاق سعري',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'الوحدة',
                hintText: 'للحجز / لليوم / لليلة',
              ),
            ),
            const SizedBox(height: Space.lg),
            const Align(alignment: AlignmentDirectional.centerStart, child: Muted('القسم')),
            const SizedBox(height: Space.sm),
            FutureBuilder<List<ServiceCategory>>(
              future: _categories,
              builder: (context, snap) {
                final rows = snap.data ?? const <ServiceCategory>[];
                if (rows.isEmpty) return const Muted('…');
                return Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final c in rows)
                      PickChip(
                        label: c.name,
                        active: _categoryId == c.id,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Space.lg),
            Align(alignment: AlignmentDirectional.centerStart, child: Muted('العربون: $_deposit٪')),
            Slider(
              value: _deposit.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_deposit٪',
              onChanged: (v) => setState(() => _deposit = v.round()),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
              ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.service == null ? 'إضافة' : 'حفظ'),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }
}
