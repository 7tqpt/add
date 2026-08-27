import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'account_extras.dart';
import '../ui/media.dart';
import 'chat.dart';
import 'provider_public.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});
  final String serviceId;
  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Future<ServiceItem?> _future;
  final _guests = TextEditingController(text: '300');
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _coupon = TextEditingController();
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _busy = false;
  String? _error;

  /// الكودُ **بعد أن تحقّق منه الخادم** — لا ما في الحقل.
  CouponCheck? _applied;
  bool _checking = false;
  String? _couponError;

  /// يملأ العنوان من الافتراضيّ إن وُجد.
  ///
  /// **وفشلُه صامتٌ عمداً:** الحقلُ يبقى فارغاً كما كان، والمستخدم يكتب —
  /// وشاشةُ خطأٍ عن دفترِ عناوينَ لم يُقرأ تمنعه من الحجز لأجل راحةٍ لم تصل.
  Future<void> _fillDefaultAddress() async {
    try {
      final saved = await Api.myAddresses();
      final def = saved.where((a) => a.isDefault).firstOrNull;
      // ولا يُكتب فوق ما كتبه بيده إن كان قد بدأ.
      if (def != null && mounted && _address.text.trim().isEmpty) {
        setState(() => _address.text = def.forBooking);
      }
    } catch (_) {}
  }

  /// يفتح دفترَ العناوين ويأخذ ما اختير.
  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (routeContext) => AddressesScreen(
          onPick: (a) => Navigator.of(routeContext).pop(a),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _address.text = picked.forBooking);
    }
  }

  /// خطط العرس المتاحة للربط. تُقرأ مرّةً عند الفتح.
  List<WeddingPlan> _plans = const [];
  String? _planId;

  @override
  void initState() {
    super.initState();
    _future = Api.service(widget.serviceId);
    _loadPlans();
    _fillDefaultAddress();
  }

  Future<void> _loadPlans() async {
    try {
      final rows = await Api.myPlans();
      if (!mounted) return;
      setState(() {
        _plans = rows;
        // خطةٌ واحدة تُختار وحدها: سؤال المستخدم عن اختيارٍ لا بديل له عبثٌ،
        // وتركُه فارغاً يُبقي الحجز خارج الخطة بلا أن ينتبه.
        if (rows.length == 1) _planId = rows.first.id;
      });
    } catch (_) {
      // الربط بالخطة إضافة: تعذُّر قراءتها لا يمنع الحجز.
    }
  }

  @override
  void dispose() {
    _guests.dispose();
    _address.dispose();
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  /// يفتح المحادثة مع صاحب الخدمة ثم يدخلها.
  ///
  /// والفتح من القاعدة: الضغطُ مرّتين بسرعة كان سينتج خيطين لو بحث التطبيق
  /// ثم أنشأ بنفسه، فتنقسم الرسائل بينهما ولا يرى أحدٌ نصفها.
  Future<void> _message(ServiceItem item) async {
    setState(() => _busy = true);
    try {
      final id = await Api.openConversation(item.providerId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherName: item.providerName,
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

  /// أيامُ المزوّد المشغولة — تُقرأ مرّةً وتُخبَّأ.
  ///
  /// **ولماذا قبل الاختيار لا بعده:** من يختار تاريخاً ثم يُردّ بـ«غير متاح»
  /// يعيد الكرّة تخميناً، وقد يترك المنصّة بعد الثالثة. والحارس في القاعدة
  /// يبقى على حاله — هذا تسهيلٌ في الشاشة لا استغناءٌ عنه.
  Set<DateTime> _busyDays = const {};
  bool _daysLoaded = false;

  Future<void> _loadBusyDays(String providerId) async {
    if (_daysLoaded) return;
    _daysLoaded = true;
    final now = DateTime.now();
    try {
      final days = await Api.blockedDays(
          providerId, now, now.add(const Duration(days: 730)));
      if (mounted) setState(() => _busyDays = days);
    } catch (_) {
      // تعذّرت القراءة: يبقى التقويم مفتوحاً والقاعدة ترفض ما لا يصحّ.
      // ميزةٌ تنقص لا شاشةٌ تسقط.
    }
  }

  Future<void> _pickDate(String providerId) async {
    await _loadBusyDays(providerId);
    if (!mounted) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _firstFreeFrom(_date ?? now.add(const Duration(days: 30))),
      selectableDayPredicate: (d) => !_busyDays.contains(DateTime(d.year, d.month, d.day)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// أوّلُ يومٍ متاحٍ من التاريخ المقترح — `initialDate` مشغولاً يرمي الإطار.
  DateTime _firstFreeFrom(DateTime start) {
    var day = DateTime(start.year, start.month, start.day);
    for (var i = 0; i < 60 && _busyDays.contains(day); i++) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  /// يسأل الخادمَ عن الكود، ويعرض **ما سيُخصم فعلاً**.
  Future<void> _checkCoupon(ServiceItem item) async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checking = true;
      _couponError = null;
    });
    try {
      final found = await Api.checkCoupon(code, item.id);
      if (mounted) setState(() => _applied = found);
    } catch (e) {
      if (mounted) {
        setState(() {
          _applied = null;
          _couponError = messageOf(e);
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _book(ServiceItem item) async {
    if (_date == null) {
      setState(() => _error = 'اختر تاريخ العرس.');
      return;
    }
    final guests = int.tryParse(_guests.text.trim());
    if (guests == null || guests <= 0) {
      setState(() => _error = 'اكتب عدد الضيوف رقماً.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'اكتب عنوان المناسبة.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final booking = await Api.createBooking(
        serviceId: item.id,
        eventDate: _date!.toIso8601String().substring(0, 10),
        eventTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        guests: guests,
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        planId: _planId,
        couponCode: _applied?.code ?? '',
      );
      if (!mounted) return;
      showMessage(
        context,
        booking.discountAmount > 0
            ? 'رقم حجزك ${booking.reference} — خُصم '
                '${formatMoney(booking.discountAmount)} بكود ${booking.couponCode}.'
            : 'رقم حجزك ${booking.reference} — العربون '
                '${formatMoney(booking.depositAmount)}.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الخدمة')),
      body: FutureBuilder<ServiceItem?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
          final item = snap.data;
          if (item == null) return const EmptyBlock(title: 'الخدمة غير موجودة');

          final deposit = (item.price * item.depositPercent / 100).round();

          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              // الوسائط فوق كل شيء: من فتح الخدمة يريد أن يرى ما يشتريه قبل
              // أن يقرأ عنه. والسعرُ تحتها لأن السعر يُحكَم عليه بعد الرؤية
              // لا قبلها.
              _Media(serviceId: widget.serviceId),
              AppCard(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SectionTitle(item.title)),
                      if (item.providerIsFeatured) ...[
                        const SizedBox(width: Space.sm),
                        const StatusBadge('مميّز', color: AppColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  // صاحبُ الخدمة بابٌ لا سطرَ نصّ.
                  //
                  // كان اسمُه هنا حرفاً رمادياً لا يُضغط، فمن أعجبته الخدمة لم
                  // يجد سبيلاً إلى بقيّة ما يعرضه صاحبُها ولا إلى ما قاله من
                  // تعامل معه. وهو لا يشتري خدمةً بل يشتري من يُسلّمه ليلةً لا
                  // تُعاد.
                  _ProviderRow(item: item),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(item.description, style: const TextStyle(height: 1.8)),
                  ],
                  const SizedBox(height: Space.md),
                  // في بطاقة المزوّد لا عند زرّ الحجز: السؤال يسبق الحجز ولا
                  // يليه. ومن لا يجد أين يسأل يذهب إلى واتساب، فيخرج الحجز
                  // من المنصّة كلّه ومعه سجلُّه.
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _message(item),
                    icon: const Icon(Icons.forum_outlined, size: 19),
                    label: Text('راسل ${item.providerName}'),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppCard(
                children: [
                  const SectionTitle('السعر'),
                  KeyValue(
                    'السعر',
                    item.priceTo == null
                        ? formatMoney(item.price)
                        : '${formatMoney(item.price)} – ${formatMoney(item.priceTo!)}',
                  ),
                  KeyValue('الوحدة', item.unit),
                  KeyValue('العربون ${item.depositPercent}٪', formatMoney(deposit)),
                  if (item.cancellationPolicyName != null)
                    KeyValue('سياسة الإلغاء', item.cancellationPolicyName!),
                  const SizedBox(height: Space.sm),
                  // السعر المعروض للاطّلاع، والمعتمد ما يحسبه الخادم عند الحجز:
                  // لو قبِل سعراً من التطبيق لأمكن حجز قاعة بريال واحد.
                  const Muted('المبلغ النهائي يحسبه النظام عند تأكيد الحجز.', size: 11),
                ],
              ),
              const SizedBox(height: Space.md),
              AppCard(
                children: [
                  const SectionTitle('احجز'),
                  const SizedBox(height: Space.md),
                  // منتقي تاريخ لا حقل نصّي: كتابة «2026-09-15» بيدك على جوال
                  // مصدرُ خطأ لا داعي له.
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(item.providerId),
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    label: Text(
                      _date == null ? 'اختر تاريخ العرس' : formatDate(_date!.toIso8601String()),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                    icon: const Icon(Icons.access_time, size: 20),
                    label: Text(
                      'الوقت: ${formatTime('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}')}',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _guests,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الضيوف'),
                  ),
                  const SizedBox(height: Space.md),
                  // **العنوانُ يملأ نفسه من الدفتر.** كان يُكتب في كل حجز،
                  // وعنوانُ بيت العرس واحدٌ لا يتغيّر: فمن حجز قاعةً ومصوّراً
                  // وكوشةً كتبه ثلاثاً وأخطأ في إحداها.
                  //
                  // ويبقى الحقلُ **قابلاً للكتابة**: عنوانُ عرسٍ في قاعةٍ غير
                  // عنوان بيت، فالدفترُ يختصر لا يحبس.
                  TextField(
                    controller: _address,
                    decoration: InputDecoration(
                      labelText: 'عنوان المناسبة',
                      hintText: 'حي السنينة — صنعاء',
                      suffixIcon: IconButton(
                        tooltip: 'من عناويني',
                        icon: const Icon(Icons.bookmark_border_rounded, size: 22),
                        onPressed: _pickAddress,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  if (_plans.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Muted('أضِفه إلى خطة العرس'),
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final p in _plans)
                          PickChip(
                            label: p.title,
                            active: _planId == p.id,
                            onTap: () => setState(() => _planId = p.id),
                          ),
                        PickChip(
                          label: 'بلا خطة',
                          active: _planId == null,
                          onTap: () => setState(() => _planId = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                  ],
                  // ── كود الخصم ─────────────────────────────────────────
                  //
                  // **ولا يُطبَّق كودٌ لم يتحقّق منه الخادم.** فلو أُرسل ما في
                  // الحقل كما هو لَظهر الخطأ بعد ضغطة «تأكيد الحجز» — بعد أن
                  // يكون العميل قد ملأ التاريخ والضيوف والعنوان.
                  TextField(
                    controller: _coupon,
                    textCapitalization: TextCapitalization.characters,
                    // **وأيُّ حرفٍ يُكتب يُسقط ما تحقّق قبله.** ومن تحقّق من
                    // كودٍ ثم بدّله بقي الخصمُ القديم معروضاً على الشاشة
                    // وأُرسل الكود القديم — وهذا كذبٌ على العميل في رقمٍ ماليّ.
                    onChanged: (_) {
                      if (_applied != null || _couponError != null) {
                        setState(() {
                          _applied = null;
                          _couponError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'كود الخصم (اختياري)',
                      hintText: 'إن كان لديك كود',
                      suffixIcon: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : TextButton(
                              onPressed: () => _checkCoupon(item),
                              child: const Text('تحقّق'),
                            ),
                    ),
                  ),
                  if (_applied != null) ...[
                    const SizedBox(height: Space.sm),
                    // مفتاحٌ لا اسمُ نصّ: عنوانُ الحقل نفسه فيه كلمة «الخصم»،
                    // فحارسٌ يبحث عن الكلمة يجدها ولو لم يُطبَّق كوبونٌ قطّ.
                    Row(
                      key: const ValueKey('coupon-applied'),
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.good),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            'خصم ${formatMoney(_applied!.discount)}'
                            '${_applied!.description.isEmpty ? '' : ' — ${_applied!.description}'}',
                            style: const TextStyle(
                                color: AppColors.good,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_couponError != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(_couponError!,
                        style: const TextStyle(
                            color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      hintText: 'أي تفاصيل يحتاجها مقدّم الخدمة',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.lg),
                  FilledButton(
                    onPressed: _busy ? null : () => _book(item),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentInk,
                            ),
                          )
                        : const Text('تأكيد الحجز'),
                  ),
                  const SizedBox(height: Space.sm),
                  const Muted(
                    'الحجز يبقى «بانتظار مقدّم الخدمة» حتى يقبله. لو اعتذر، يُستردّ كل ما دفعته.',
                    size: 11,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// صفُّ المزوّد: حرفُه في قرص، واسمُه، وتقييمُه، وسهمٌ إلى ملفّه.
///
/// وله أرضيّةٌ وحدٌّ لأنه داخل بطاقةٍ بيضاء: عنصرٌ يُضغط داخل بطاقةٍ لا تُضغط
/// يجب أن يقول عن نفسه إنه يُضغط، وإلا بقي حرفاً بين حروف.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.item});
  final ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: AppColors.accent.withValues(alpha: Tint.row),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PublicProviderScreen(
              providerId: item.providerId,
              name: item.providerName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: Tint.disc),
                ),
                child: Text(
                  item.providerName.isEmpty ? '؟' : item.providerName.characters.first,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.providerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (item.providerVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedMark(size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(child: Muted(item.providerGovernorate, size: 11)),
                        if (item.providerRating > 0) ...[
                          const SizedBox(width: Space.sm),
                          Rating(item.providerRating, count: item.providerReviewsCount, size: 11),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.xs),
              const Muted('عرض ملفّه', size: 11),
              // «forward» لا «back»: أيقونات الأسهم تنعكس مع اتجاه النصّ، فـ
              // «back» في العربية يشير يميناً — أي رجوعاً.
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// وسائط الخدمة في شاشة العميل — صورٌ تُمرَّر، ثم المقطعان.
///
/// **وغيابُها غيابٌ صامت:** خدمةٌ بلا وسائط لا تعرض إطاراً فارغاً ولا رسالة
/// «لا صور» — تلك تقول للعميل إن شيئاً ينقص، وهو لا يملك إصلاحه. تختفي
/// الكتلة كلّها وتبقى الشاشة كما كانت.
///
/// ونداءٌ مستقلٌّ عن الخدمة: عطبُ الوسائط لا يجوز أن يمنع الحجز — من فتح
/// الشاشة ليحجز يحجز، ولو تعذّرت الصور.
class _Media extends StatefulWidget {
  const _Media({required this.serviceId});
  final String serviceId;

  @override
  State<_Media> createState() => _MediaState();
}

class _MediaState extends State<_Media> {
  late final Future<List<ServiceMedia>> _future = Api.serviceMedia(widget.serviceId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceMedia>>(
      future: _future,
      builder: (context, snap) {
        final all = snap.data ?? const <ServiceMedia>[];
        if (all.isEmpty) return const SizedBox.shrink();

        final images = all.where((m) => m.kind == MediaKind.image).toList();
        final video = all.where((m) => m.kind == MediaKind.video).firstOrNull;
        final audio = all.where((m) => m.kind == MediaKind.audio).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (images.isNotEmpty) ...[
              _Gallery(images: images),
              const SizedBox(height: Space.md),
            ],
            if (video != null) ...[
              VideoBox(url: Api.mediaUrl(video.path), seconds: video.durationSeconds),
              const SizedBox(height: Space.md),
            ],
            if (audio != null) ...[
              AudioBar(
                url: Api.mediaUrl(audio.path),
                seconds: audio.durationSeconds,
                label: audio.title.isEmpty ? 'استمع قبل أن تحجز' : audio.title,
              ),
              const SizedBox(height: Space.md),
            ],
          ],
        );
      },
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});
  final List<ServiceMedia> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final m in widget.images) MediaThumb(url: Api.mediaUrl(m.path)),
              ],
            ),
          ),
        ),
        // النقاط تغيب مع الصورة الواحدة: نقطةٌ واحدة تحت صورةٍ واحدة تقول
        // شيئاً لا معنى له.
        if (widget.images.length > 1) ...[
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.images.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.accent : AppColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
