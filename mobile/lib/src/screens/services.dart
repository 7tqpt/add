import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/motion.dart';
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
      showMessage(context, service.isActive ? tr('أُوقفت الخدمة') : tr('عادت الخدمة للعرض'));
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// حذفُ خدمةٍ — بسؤالٍ قبله، وبمنعٍ إن كان عليها حجزٌ قادم.
  ///
  /// **والمنعُ يقع في القاعدة لا هنا.** سياسةُ `provider_services_owner`
  /// تسمح لصاحب الخدمة بالحذف مباشرةً، فحارسٌ في هذه الشاشة يُتجاوَز بملفِّ
  /// APK مفكوك. فتُنادى `api_delete_service` وتردّ **حقيقةً**: `deleted`
  /// وتاريخَ الحجز المانع. وهذه الشاشةُ تصوغها بلغتها وتنسّق تاريخَها —
  /// ولذلك لا تُرمى رسالةٌ عربيّةٌ من الخادم: تصل كما هي فلا تُترجَم.
  Future<void> _delete(MyService service) async {
    final ok = await confirmDanger(
      context,
      title: tr('حذف الخدمة'),
      body: trf('هل تريد حذف «{0}»؟ لا رجعة بعدها — وتُحذف صورُها ومقاطعُها معها.',
          [service.title]),
      confirm: tr('نعم، احذفها'),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyId = service.id);
    try {
      final result = await Api.deleteService(service.id);
      if (!mounted) return;
      if (!result.deleted) {
        // **ويُقال له ما يفعل بدلَها، لا «مُنعت» وحدَها.** الإيقافُ يُخفيها
        // عن العملاء ويُبقي الحجزَ القائم.
        final date = result.blockingDate;
        showMessage(
          context,
          date == null
              ? tr('عليها حجزٌ قادم. أوقِفها بدل أن تحذفها.')
              : trf('عليها حجزٌ في {0}. أوقِفها بدل أن تحذفها.',
                  [formatDay(date)]),
        );
        return;
      }
      showMessage(context, tr('حُذفت الخدمة'));
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
      body: FutureBuilder<List<MyService>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonList(rows: 3);
          }
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <MyService>[];
          // ── «خدمة جديدة» — شريطٌ في صدر الشاشة ────────────────────────
          //
          // **وكان زرّاً عائماً في القاع**، ثمّ أرسل صاحبُ المنصّة تصميماً
          // فيه شريطٌ في الصدر، فبُدّل. وذهب معه عطبٌ كان يلازمه: الزرُّ
          // العائمُ يقف على قاع سقّالةٍ ذاتِ `extendBody`، فينزل خلفَ
          // الشريط الزجاجيّ فلا يُضغط — وقد شُكي منه.
          //
          // **وهو خارج القائمة لا أوّلَ صفوفها.** جُعل أوّلَ صفٍّ فيها أوّلَ
          // مرّة، فاختفى مع القائمة حين لا خدمةَ أصلاً — **فبقي من لا
          // خدمةَ له بلا بابٍ يُضيف منه**، وهي أوّلُ حالٍ يقع فيها كلُّ
          // مزوّدٍ جديد. كشفه اختبارٌ يفتح الورقةَ على قائمةٍ فارغة.
          final addBar = Padding(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, Space.md),
            child: FilledButton.icon(
              key: const ValueKey('new-service'),
              onPressed: _busyId == null ? () => _edit() : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(tr('خدمة جديدة')),
            ),
          );

          if (rows.isEmpty) {
            return Column(
              children: [
                addBar,
                Expanded(
                  child: EmptyBlock(
                    title: tr('لا خدمات بعد'),
                    description: tr(
                        'أضف ما تقدّمه بسعره وعربونه، ليظهر للعملاء في الاستكشاف.'),
                  ),
                ),
              ],
            );
          }
          // **وتُسحب للتحديث كأخواتها.** كانت هذه و«استكشف» وحدَهما بلا
          // سحب، فمن غيّر شيئاً من شاشةٍ أخرى — أو شكّ أنّ قائمتَه قديمة —
          // لم يكن له إلّا أن يخرج ويعود.
          return Column(
            children: [
              addBar,
              Expanded(
                child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
            // **والمسافةُ ثابتُ الشريط لا رقمٌ مكتوبٌ بيده**: زاد الشريطُ
            // بالقرص المرتفع، ورقمٌ منسوخٌ هنا يبقى على قدره القديم فيحجب
            // آخرَ خدمة.
            padding: EdgeInsets.fromLTRB(
              Space.lg, 0, Space.lg, glassNavSpace),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final s = rows[i];
              return FadeSlideIn(index: i, child: AppCard(
                // **والبطاقةُ كلُّها تفتح التعديل.** «أحسّ تطبيقَ متحجّز،
                // البطاقات غير قابلة للضغط» — وكانت هذه ساكنةً مهما ضُغطت،
                // فيُبحث عن زرٍّ صغيرٍ في أسفلها. وهي تنخفض تحت الإصبع الآن
                // بـ`Pressable` داخلَ `AppCard`.
                //
                // **وزرُّ «تعديل» يبقى معها**: البطاقةُ فيها أزرارٌ أخرى،
                // فمن يقرأ يختار، ومن يضغط حيث لا زرَّ يفتح الأشهرَ منها.
                onTap: _busyId == null ? () => _edit(s) : null,
                children: [
                  // المعطَّلة تحمل شارتها: بلا علامةٍ ظاهرة يظنّ صاحبها أنها
                  // معروضة، ويسأل لماذا لا تصله طلبات.
                  //
                  // **والسهمُ يقول إنّها تُفتح** — اختاره صاحبُ المنصّة:
                  // الانخفاضُ تحت الإصبع لا يُعلم إلّا بعد أن يُجرَّب، والسهمُ
                  // يُعلم قبله.
                  CardTitleBar(
                    s.title,
                    subtitle: s.description,
                    badge: s.isActive ? tr('معروضة') : tr('موقوفة'),
                    // **ولونُ الشارة يفرّق الحالَين بلمحة**: المعروضةُ
                    // خضراء والموقوفةُ باهتة — وعلى الشريط النبيذيّ القديم
                    // كانتا بيضاوين تُقرآن حرفاً حرفاً.
                    badgeColor: s.isActive ? AppColors.good : AppColors.muted,
                    opens: true,
                  ),
                  const SizedBox(height: Space.sm),
                  // **والوحدةُ تفترق عن المبلغ** — كما في تصميم صاحب
                  // المنصّة: «١٠٬٠٠٠ – ١٠٠٬٠٠٠ ر.ي» بارزاً، و«لليوم»
                  // باهتاً إلى جانبه، فلا يُقرأ الاثنان رقماً واحداً.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          s.priceTo == null
                              ? formatMoney(s.price)
                              : '${formatMoney(s.price)} – '
                                  '${formatMoney(s.priceTo!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Muted(s.unit, size: 12, maxLines: 1),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(trf('العربون {0}٪', ['${s.depositPercent}']), size: 11),
                  const SizedBox(height: Space.sm),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busyId == null ? () => _edit(s) : null,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(tr('تعديل')),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busyId == null ? () => _toggle(s) : null,
                          icon: Icon(
                            s.isActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink2,
                            side: const BorderSide(color: AppColors.hairline),
                          ),
                          label: Text(s.isActive ? tr('إيقاف') : tr('عرض')),
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
                    // **رماديٌّ لا ورديّ** — كما في تصميم صاحب المنصّة.
                    // وصبغةُ الثيمة النبيذيّةُ تجعله يُزاحم «حذف الخدمة»
                    // تحته في اللون، وهما فعلان لا يجتمعان.
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.ink2,
                    ),
                    icon: const Icon(Icons.perm_media_outlined, size: 19),
                    label: Text(tr('الصور والمقاطع')),
                  ),
                  const SizedBox(height: Space.sm),
                  // **مصبوغٌ بحدٍّ أحمر لا مصمتاً** — وكان مصمتاً باختياره
                  // من ثلاثٍ عُرضت عليه، ثمّ أرسل تصميماً فيه مصبوغ.
                  // **والأحمرُ باقٍ حرفاً وحدّاً**، فلا يُقرأ فعلاً عاديّاً.
                  FilledButton.icon(
                    key: ValueKey('service-delete-${s.id}'),
                    onPressed: _busyId == null ? () => _delete(s) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.critical.withValues(alpha: 0.07),
                      foregroundColor: AppColors.critical,
                      side: BorderSide(
                        color: AppColors.critical.withValues(alpha: 0.55),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    label: Text(tr('حذف الخدمة')),
                  ),
                ],
              ));
            },
            ),
                ),
              ),
            ],
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
  late final _unit = TextEditingController(text: widget.service?.unit ?? tr('للحجز'));
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
      setState(() => _error = tr('اكتب اسم الخدمة وسعرها، واختر قسمها.'));
      return;
    }
    // القاعدة تفرض `price_to >= price` بقيد، ورفضُها يصل نصّاً إنجليزياً غامضاً.
    // الشرط هنا يقوله بالعربية قبل أن يُرسَل.
    if (priceTo != null && priceTo < price) {
      setState(() => _error = tr('أعلى السعر لا يكون أقلّ من أدناه.'));
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
        unit: _unit.text.trim().isEmpty ? tr('للحجز') : _unit.text.trim(),
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
            SectionTitle(widget.service == null ? tr('خدمة جديدة') : tr('تعديل الخدمة')),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: tr('اسم الخدمة'),
                hintText: tr('قاعة التاج — باقة شاملة'),
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('الوصف'),
                hintText: tr('ما الذي تشمله الباقة؟'),
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
                    decoration: InputDecoration(labelText: tr('السعر (ر.ي)')),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextField(
                    controller: _priceTo,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('إلى (اختياري)'),
                      hintText: tr('لنطاق سعري'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _unit,
              decoration: InputDecoration(
                labelText: tr('الوحدة'),
                hintText: tr('للحجز / لليوم / لليلة'),
              ),
            ),
            const SizedBox(height: Space.lg),
            // **نفسُ طراز حقل القسم في `become_provider.dart` بحرفه** —
            // تسميةٌ عائمةٌ دائماً، وتلميحٌ رماديّ. كان شريطَ شرائح فطُلب
            // منسدلةً كحقل المحافظة وحقل القسم هناك.
            FutureBuilder<List<ServiceCategory>>(
              future: _categories,
              builder: (context, snap) {
                final rows = snap.data ?? const <ServiceCategory>[];
                if (rows.isEmpty) return const Muted('…');
                return DropdownButtonFormField<String>(
                  key: const ValueKey('service-category-field'),
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('القسم'),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  hint: Text(tr('اختر القسم'), style: const TextStyle(color: AppColors.muted)),
                  items: [
                    for (final c in rows)
                      DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                );
              },
            ),
            const SizedBox(height: Space.lg),
            Align(alignment: AlignmentDirectional.centerStart, child: Muted(trf('العربون: {0}٪', ['$_deposit']))),
            Slider(
              value: _deposit.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: trf('{0}٪', ['$_deposit']),
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
              child: Text(widget.service == null ? tr('إضافة') : tr('حفظ')),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: Text(tr('إلغاء')),
            ),
          ],
        ),
      ),
    );
  }
}
