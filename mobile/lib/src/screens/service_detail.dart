import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/media.dart';

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
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _busy = false;
  String? _error;

  /// خطط العرس المتاحة للربط. تُقرأ مرّةً عند الفتح.
  List<WeddingPlan> _plans = const [];
  String? _planId;

  @override
  void initState() {
    super.initState();
    _future = Api.service(widget.serviceId);
    _loadPlans();
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
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _date ?? now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
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
      );
      if (!mounted) return;
      showMessage(
        context,
        'رقم حجزك ${booking.reference} — العربون ${formatMoney(booking.depositAmount)}.',
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
                  const SizedBox(height: Space.xs),
                  Row(
                    children: [
                      Flexible(child: Muted('${item.providerName} · ${item.providerGovernorate}')),
                      if (item.providerRating > 0) ...[
                        const SizedBox(width: Space.sm),
                        Rating(item.providerRating, count: item.providerReviewsCount),
                      ],
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(item.description, style: const TextStyle(height: 1.8)),
                  ],
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
                    onPressed: _pickDate,
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
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'عنوان المناسبة',
                      hintText: 'حي السنينة — صنعاء',
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
