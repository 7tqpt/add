import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../core/theme.dart';
import '../ui/celebrate.dart';
import '../ui/kit.dart';
import '../ui/media.dart';
import 'account_extras.dart';
import 'map_picker.dart';

/// حجزُ خدمةٍ في ثلاث خطوات: الخدمة ← الموعد ← التأكيد.
///
/// ── ما كان قبلها ───────────────────────────────────────────────────────────
///
/// نموذجٌ واحدٌ طويلٌ في ذيل صفحة الخدمة: تاريخٌ ووقتٌ وضيوفٌ وعنوانٌ ونقطةٌ
/// على الخريطة وخطّةٌ وكودُ خصمٍ وملاحظات، ثمّ «تأكيد الحجز» — **ولا مراجعةَ
/// بينه وبين الإرسال**. فمن أخطأ في التاريخ أو العنوان لم يُعرض عليه ما
/// سيُرسل قبل أن يُرسَل، ولم يرَ ما سيدفعه إلّا بعد أن وقع الحجز.
///
/// ── ولماذا ثلاثٌ لا اثنتان ولا أربع ────────────────────────────────────────
///
/// **كلُّ خطوةٍ تجمع ما يُسأل عنه في مجلسٍ واحد:**
///
///   ١ · الخدمة — ما يعرفه صاحبُه عن عرسه: كم ضيفاً، وما يريد أن يقوله
///       لمقدّم الخدمة. ولا يحتاج تقويماً ولا خريطة.
///   ٢ · الموعد — متى وأين: تاريخٌ ووقتٌ وعنوانٌ ونقطةٌ وخطّةٌ وكود.
///   ٣ · التأكيد — لا يُكتب فيها شيءٌ البتّة. تُقرأ فقط.
///
/// ── والخطوةُ الثالثة تَعِد برقمٍ ماليّ، والوعدُ يُقيَّد ───────────────────
///
/// **الأرقامُ فيها تقديرُ التطبيق لا حكمُ الخادم**، ويُقال ذلك تحتها نصّاً.
/// والخادمُ هو من يحسب السعرَ والعربونَ والعمولةَ وسلّمَ الإلغاء عند
/// `api_create_booking` — ولو قُبل سعرٌ من التطبيق لَأمكن حجزُ قاعةٍ بريال.
///
/// فما يُعرض هنا يُشتقّ من `item.price` و`depositPercent` وخصمِ كودٍ **تحقّق
/// منه الخادمُ** — لا من حقلٍ في الشاشة. وقد يفترق عمّا يحسبه الخادمُ إن
/// انتهى الكودُ أو بدّل المزوّدُ سعرَه بين العرض والضغط، ولذلك يُسمّى
/// تقديراً ولا يُسمّى مبلغاً.
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key, required this.item});
  final ServiceItem item;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  /// ‎٠‎ الخدمة · ‎١‎ الموعد · ‎٢‎ التأكيد.
  int _step = 0;

  final _guests = TextEditingController(text: '300');
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _coupon = TextEditingController();

  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _busy = false;
  String? _error;

  /// موقعُ المناسبة — يأتي مع العنوان من الدفتر، أو يُحدَّد هنا.
  GeoPoint? _point;

  /// الكودُ **بعد أن تحقّق منه الخادم** — لا ما في الحقل.
  CouponCheck? _applied;
  bool _checking = false;
  String? _couponError;

  /// خطط العرس المتاحة للربط. تُقرأ مرّةً عند الفتح.
  List<WeddingPlan> _plans = const [];
  String? _planId;

  Set<DateTime> _busyDays = const {};
  bool _daysLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _fillDefaultAddress();
  }

  @override
  void dispose() {
    _guests.dispose();
    _address.dispose();
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  // ── ما يُقرأ عند الفتح ────────────────────────────────────────────────────

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
        setState(() {
          _address.text = def.forBooking;
          _point = def.point;
        });
      }
    } catch (_) {}
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

  Future<void> _loadBusyDays(String providerId) async {
    if (_daysLoaded) return;
    _daysLoaded = true;
    final now = DateTime.now();
    try {
      final days = await Api.blockedDays(providerId, now, now.add(const Duration(days: 730)));
      if (mounted) setState(() => _busyDays = days);
    } catch (_) {
      // تعذّرت القراءة: يبقى التقويم مفتوحاً والقاعدة ترفض ما لا يصحّ.
      // ميزةٌ تنقص لا شاشةٌ تسقط.
    }
  }

  // ── ما يفعله صاحبُه ───────────────────────────────────────────────────────

  /// يفتح دفترَ العناوين ويأخذ ما اختير.
  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (routeContext) =>
            AddressesScreen(onPick: (a) => Navigator.of(routeContext).pop(a)),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _address.text = picked.forBooking;
        // **ونقطتُه معه:** من حفظ موقع بيته مرّةً لا يحدّده في كل حجز.
        _point = picked.point;
      });
    }
  }

  Future<void> _pickDate() async {
    await _loadBusyDays(widget.item.providerId);
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
  Future<void> _checkCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checking = true;
      _couponError = null;
    });
    try {
      final found = await Api.checkCoupon(code, widget.item.id);
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

  // ── الأرقام: تقديرُ الشاشة، والحكمُ للخادم ────────────────────────────────

  int get _guestCount => int.tryParse(_guests.text.trim()) ?? 0;

  num get _discount => _applied?.discount ?? 0;

  /// قيمةُ الحجز بعد الخصم. و`price` لا `priceTo`: النطاقُ يُعرض في صفحة
  /// الخدمة، والحجزُ يقع على حدّه الأدنى حتى يحسب الخادمُ غيرَه.
  num get _total {
    final after = widget.item.price - _discount;
    return after < 0 ? 0 : after;
  }

  int get _deposit => (_total * widget.item.depositPercent / 100).round();

  num get _remaining => _total - _deposit;

  // ── الانتقال بين الخطوات ──────────────────────────────────────────────────

  /// ما ينقص هذه الخطوةَ كي تُغادَر، أو `null` إن تمّت.
  ///
  /// **ويُقاس ما في الحقول لا ما في النيّة:** خطوةٌ تُغادَر ناقصةً تُوصِل
  /// صاحبَها إلى شاشة المراجعة بتاريخٍ فارغٍ، فيقرأ «—» ويظنّ العطبَ فيها.
  String? _missing(int step) {
    if (step == 0) {
      if (_guestCount <= 0) return tr('اكتب عدد الضيوف رقماً.');
      return null;
    }
    if (step == 1) {
      if (_date == null) return tr('اختر تاريخ العرس.');
      if (_address.text.trim().isEmpty) return tr('اكتب عنوان المناسبة.');
      return null;
    }
    return null;
  }

  void _next() {
    final missing = _missing(_step);
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = null;
      _step--;
    });
  }

  // ── الإرسال ───────────────────────────────────────────────────────────────

  Future<void> _book() async {
    // **ويُعاد الفحصُ هنا ولو مرّ في كلّ خطوة.** من رجع إلى الثانية وفرّغ
    // العنوان ثمّ تقدّم لا يمرّ به الحارسُ ثانيةً، والشاشةُ لا تُمنع من
    // العرض — فيُرسَل حجزٌ بلا عنوان.
    for (var step = 0; step < 2; step++) {
      final missing = _missing(step);
      if (missing != null) {
        setState(() {
          _error = missing;
          _step = step;
        });
        return;
      }
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final booking = await Api.createBooking(
        serviceId: widget.item.id,
        eventDate: _date!.toIso8601String().substring(0, 10),
        eventTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        guests: _guestCount,
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        planId: _planId,
        couponCode: _applied?.code ?? '',
        point: _point,
      );
      if (!mounted) return;
      // **وتُطفأ الدوّارةُ قبل التهنئة لا بعدها.** شاشةُ التهنئة تنتظر
      // صاحبَها حتى يُغلقها، فلو بقي `_busy` صادقاً لَظلّ الزرُّ يدور تحتها
      // ما دامت مفتوحة — ويراه من رجع بزرّ النظام يدور على حجزٍ قد تمّ.
      setState(() => _busy = false);

      // **والخبرُ في شاشةٍ تبقى لا في شريطٍ يمرّ.** فيه رقمُ الحجز ومبلغُ
      // العربون، وهما ما يحتاجه صاحبُه ليحوّل.
      await showCelebration(
        context,
        title: tr('تمّ حجزك'),
        body: booking.discountAmount > 0
            ? trf('رقم حجزك {0}\nخُصم {1} بكود {2}', [
                booking.reference,
                formatMoney(booking.discountAmount),
                booking.couponCode,
              ])
            : trf('رقم حجزك {0}\nالعربون {1}', [
                booking.reference,
                formatMoney(booking.depositAmount),
              ]),
        actionLabel: tr('إلى حجوزاتي'),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── البناء ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final review = _step == 2;
    return PopScope(
      // الرجوعُ يخطو خطوةً إلى الوراء لا يُغلق الشاشة — ومن ملأ خطوتين ثمّ
      // ضغط رجوعاً ليصحّح حرفاً لا يُرمى ما كتبه.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(review ? tr('مراجعة الحجز') : tr('احجز')),
          centerTitle: true,
        ),
        bottomNavigationBar: _bottomBar(review),
        body: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            _StepHeader(active: _step),
            const SizedBox(height: Space.lg),
            if (_step == 0) ..._serviceStep(),
            if (_step == 1) ..._dateStep(),
            if (_step == 2) ..._reviewStep(),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
            ],
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    );
  }

  /// الشريطُ السفليّ — وفي المراجعة يحمل المبلغَ إلى جانب الزرّ.
  Widget _bottomBar(bool review) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (review) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Muted(tr('المطلوب الآن'), size: 11),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(_deposit),
                      key: const ValueKey('due-now'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: Space.lg),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : (review ? _book : _next),
                  child: _busy
                      ? const ButtonSpinner()
                      : Text(review ? tr('متابعة الدفع') : tr('التالي')),
                ),
              ),
            ],
          ),
        ),
      );

  // ── ١ · الخدمة ────────────────────────────────────────────────────────────

  List<Widget> _serviceStep() => [
        AppCard(
          children: [
            SectionTitle(widget.item.title),
            const SizedBox(height: Space.sm),
            Muted(widget.item.providerName),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          children: [
            SectionTitle(tr('عن مناسبتك')),
            const SizedBox(height: Space.md),
            TextField(
              controller: _guests,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('عدد الضيوف')),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('ملاحظات (اختياري)'),
                hintText: tr('أي تفاصيل يحتاجها مقدّم الخدمة'),
              ),
            ),
          ],
        ),
      ];

  // ── ٢ · الموعد ────────────────────────────────────────────────────────────

  List<Widget> _dateStep() => [
        AppCard(
          children: [
            SectionTitle(tr('متى وأين')),
            const SizedBox(height: Space.md),
            // منتقي تاريخ لا حقل نصّي: كتابة «2026-09-15» بيدك على جوال
            // مصدرُ خطأ لا داعي له.
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              label: Text(
                _date == null ? tr('اختر تاريخ العرس') : formatDate(_date!.toIso8601String()),
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
                trf('الوقت: {0}', [
                  formatTime(
                    '${_time.hour.toString().padLeft(2, '0')}'
                    ':${_time.minute.toString().padLeft(2, '0')}',
                  ),
                ]),
              ),
            ),
            const SizedBox(height: Space.md),
            // **العنوانُ يملأ نفسه من الدفتر.** كان يُكتب في كل حجز، وعنوانُ
            // بيت العرس واحدٌ لا يتغيّر: فمن حجز قاعةً ومصوّراً وكوشةً كتبه
            // ثلاثاً وأخطأ في إحداها. ويبقى الحقلُ قابلاً للكتابة.
            TextField(
              controller: _address,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('عنوان المناسبة'),
                hintText: tr('حي السنينة — صنعاء'),
                suffixIcon: IconButton(
                  tooltip: tr('من عناويني'),
                  icon: const Icon(Icons.bookmark_border_rounded, size: 22),
                  onPressed: _pickAddress,
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            // موقعُ العرس على الخريطة — يصل مقدّمَ الخدمة فيفتحه في خرائط
            // جهازه بدل أن يتّصل ليسأل عن الطريق.
            LocationRow(
              point: _point,
              governorate: '',
              onChanged: (p) => setState(() => _point = p),
            ),
          ],
        ),
        if (_plans.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          AppCard(
            children: [
              SectionTitle(tr('خطة العرس')),
              const SizedBox(height: Space.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Muted(tr('أضِفه إلى خطة العرس')),
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
                    label: tr('بلا خطة'),
                    active: _planId == null,
                    onTap: () => setState(() => _planId = null),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: Space.md),
        AppCard(
          children: [
            SectionTitle(tr('كود الخصم')),
            const SizedBox(height: Space.md),
            // **ولا يُطبَّق كودٌ لم يتحقّق منه الخادم.**
            TextField(
              controller: _coupon,
              textCapitalization: TextCapitalization.characters,
              // **وأيُّ حرفٍ يُكتب يُسقط ما تحقّق قبله.** ومن تحقّق من كودٍ
              // ثم بدّله بقي الخصمُ القديم معروضاً وأُرسل الكود القديم —
              // وهذا كذبٌ على العميل في رقمٍ ماليّ.
              onChanged: (_) {
                if (_applied != null || _couponError != null) {
                  setState(() {
                    _applied = null;
                    _couponError = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: tr('كود الخصم (اختياري)'),
                hintText: tr('إن كان لديك كود'),
                suffixIcon: _checking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(onPressed: _checkCoupon, child: Text(tr('تحقّق'))),
              ),
            ),
            if (_applied != null) ...[
              const SizedBox(height: Space.sm),
              // مفتاحٌ لا اسمُ نصّ: عنوانُ الحقل نفسه فيه كلمة «الخصم»،
              // فحارسٌ يبحث عن الكلمة يجدها ولو لم يُطبَّق كوبونٌ قطّ.
              Row(
                key: const ValueKey('coupon-applied'),
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.good),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      _applied!.description.isEmpty
                          ? trf('خصم {0}', [formatMoney(_applied!.discount)])
                          : trf('خصم {0} — {1}', [
                              formatMoney(_applied!.discount),
                              _applied!.description,
                            ]),
                      style: const TextStyle(
                        color: AppColors.good,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_couponError != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                _couponError!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ],
          ],
        ),
      ];

  // ── ٣ · التأكيد ───────────────────────────────────────────────────────────

  List<Widget> _reviewStep() => [
        // مقدّمُ الخدمة
        AppCard(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.providerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.item.providerGovernorate.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                          const SizedBox(width: 3),
                          Muted(widget.item.providerGovernorate, size: 12),
                        ]),
                      const SizedBox(height: 6),
                      Rating(
                        widget.item.providerRating,
                        count: widget.item.providerReviewsCount,
                      ),
                      if (widget.item.providerVerified) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const VerifiedMark(size: 15),
                          const SizedBox(width: 4),
                          Muted(tr('مزوّد موثّق'), size: 11),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 74,
                    // نفسُ ما ترسمه بطاقةُ الخدمة في القوائم — فالصورةُ التي
                    // اختار منها هي التي يراها في المراجعة.
                    child: MediaThumb(url: Api.mediaUrl(widget.item.coverPath)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Space.md),

        // الموعد
        AppCard(
          children: [
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date == null ? tr('لم يُختَر تاريخ') : formatDate(_date!.toIso8601String()),
                      key: const ValueKey('review-date'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Muted(_address.text.trim(), size: 12),
                  ],
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: Space.md),

        // المال
        AppCard(
          children: [
            Row(children: [
              const Icon(Icons.payments_outlined, size: 19, color: AppColors.accent),
              const SizedBox(width: Space.sm),
              SectionTitle(tr('قيمة الحجز')),
            ]),
            const SizedBox(height: Space.sm),
            KeyValue(tr('قيمة الحجز'), formatMoney(widget.item.price)),
            if (_discount > 0) KeyValue(tr('الخصم'), '− ${formatMoney(_discount)}'),
            KeyValue(tr('العربون الآن'), formatMoney(_deposit)),
            KeyValue(tr('المتبقّي'), formatMoney(_remaining)),
            const SizedBox(height: Space.xs),
            // **ويُقال إنّه تقدير.** الخادمُ يحسب السعرَ والعمولةَ والسلّم عند
            // التأكيد، وقد يفترق إن انتهى الكودُ أو بدّل المزوّدُ سعرَه بين
            // العرض والضغط. ورقمٌ يُعرض على أنّه نهائيٌّ ثمّ يتبدّل أسوأُ من
            // رقمٍ قيل إنّه تقدير.
            Muted(tr('تقديرٌ — والمبلغ النهائي يحسبه النظام عند تأكيد الحجز.'), size: 11),
          ],
        ),

        if (widget.item.cancellationPolicyName != null) ...[
          const SizedBox(height: Space.md),
          _CancellationCard(name: widget.item.cancellationPolicyName!),
        ],
      ];
}

// ============================================================================
//  رأسُ الخطوات
// ============================================================================

/// ثلاثُ نقاطٍ مرقَّمةٍ يصلها خطّ — والقائمةُ منها مملوءة.
///
/// **والترقيمُ يحمل معنًى لا زينة:** المسارُ ثلاثُ خطواتٍ بترتيبٍ لازم، فمن
/// رأى «٢» عرف أنّ قبلها واحدةً وبعدها ثالثة. ولو كان المسارُ اختياراتٍ
/// متفرّقةً لَكان الترقيمُ كذباً على شكل ترتيب.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.active});

  /// ‎٠‎ الخدمة · ‎١‎ الموعد · ‎٢‎ التأكيد.
  final int active;

  @override
  Widget build(BuildContext context) {
    Widget dot(int index, String title) {
      final on = index == active;
      final done = index < active;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.accent : AppColors.surface,
              border: Border.all(
                color: on || done ? AppColors.accent : AppColors.hairline,
                width: 1.4,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: AppColors.accent)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.accentInk : AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? AppColors.ink : AppColors.muted,
            ),
          ),
        ],
      );
    }

    Widget line(bool filled) => Expanded(
          child: Container(
            height: 1.4,
            margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
            color: filled ? AppColors.accent : AppColors.hairline,
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dot(0, tr('الخدمة')),
        line(active >= 1),
        dot(1, tr('الموعد')),
        line(active >= 2),
        dot(2, tr('التأكيد')),
      ],
    );
  }
}

// ============================================================================
//  سياسة الإلغاء — تُطوى
// ============================================================================

/// **وتبدأ مطويّةً ويُقال ما فيها.** شروطُ الإلغاء سطورٌ لا يقرؤها من جاء
/// ليحجز، ونشرُها في شاشة المراجعة يدفن ما فوقها. ومن أراد قرأ.
class _CancellationCard extends StatefulWidget {
  const _CancellationCard({required this.name});

  /// اسمُ السياسة كما يعرضه الخادم. **ولا تفاصيلَ لها في هذا النموذج** —
  /// `ServiceItem` تحمل الاسمَ وحدَه، وسلّمُ الاسترداد يُحسب في الخادم عند
  /// الإلغاء. فيُعرض ما نملك ولا يُختلق ما لا نملك.
  final String name;

  @override
  State<_CancellationCard> createState() => _CancellationCardState();
}

class _CancellationCardState extends State<_CancellationCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => AppCard(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('سياسة الإلغاء'),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Muted(tr('راجع الشروط قبل تأكيد الطلب'), size: 11.5),
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 22,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: Space.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                widget.name,
                style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.ink2),
              ),
            ),
          ],
        ],
      );
}
