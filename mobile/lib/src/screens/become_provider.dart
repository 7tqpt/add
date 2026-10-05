import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/auth_frame.dart' show authGoldEdge, authPaper;
import '../ui/kit.dart';
import 'onboarding.dart' show DialPicker, YemenFlag;

/// «أريد تقديم خدمة».
///
/// كل من يسجّل يبدأ عميلاً، وهذه الشاشة تضيف له ملفَّ مقدّم خدمة **قيد
/// المراجعة** — لا تحوّله ولا تسحب منه صفة العميل.
class BecomeProviderScreen extends StatefulWidget {
  const BecomeProviderScreen({super.key, required this.session});
  final Session session;
  @override
  State<BecomeProviderScreen> createState() => _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends State<BecomeProviderScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  String? _governorate;

  /// مفتاحُ الدولة بجانب الرقم — اليمنُ ابتداءً، و`null` لـ«دولة أخرى».
  /// كما في «أكمل ملفك»، وبالمنتقي نفسِه.
  String? _dial = '967';

  /// **قسمٌ واحدٌ لا مجموعة.** قرّر صاحبُ المنصّة أنّ المزوّد لا يعمل في
  /// أكثر من قسم: القاعةُ قاعةٌ ولا تطبخ. وكان الحقلُ اختياراً متعدّداً.
  ///
  /// و**القسمُ غيرُ الخدمة**: المزوّدُ يعرض داخلَ قسمه باقاتٍ عدّة
  /// (`provider_services`) — وتلك لم تُمسّ.
  String? _category;
  late Future<(List<Governorate>, List<ServiceCategory>)> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Governorate>, List<ServiceCategory>)> _load() async =>
      (await Api.governorates(), await Api.categories());

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // **والنبذةُ صارت مطلوبةً كالبقيّة** — عليها نجمةٌ في صورة صاحب المنصّة،
    // وهي أوّلُ ما يقرؤه العريسُ في صفحة المزوّد.
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _bio.text.trim().isEmpty ||
        _governorate == null ||
        _category == null) {
      setState(() => _error = tr('اكتب اسم المنشأة ورقمك ونبذةً عن خدمتك، واختر محافظتك وقسمك.'));
      return;
    }
    // ورقمُ المنشأة كرقم العميل: يُفحص شكلُه ويُحفظ مطهَّراً — وهو الرقمُ
    // الذي يتّصل به من يريد أن يحجز. **ويُجمع إلى مفتاحه** كما في «أكمل ملفك».
    final phone = composePhone(_dial, _phone.text);
    if (phone == null) {
      setState(() => _error = tr('رقم الجوال غير مكتمل. اكتبه مع مفتاح الدولة، مثل +967 7XX XXX XXX.'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.applyAsProvider(
        businessName: _name.text.trim(),
        phone: phone,
        bio: _bio.text.trim(),
        governorate: _governorate!,
        categoryId: _category!,
      );
      await widget.session.refreshIdentity();
      if (!mounted) return;
      widget.session.switchTo(provider: true);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── على صورة صاحب المنصّة ──────────────────────────────────────────────────
  //
  // عنوانٌ فوق كلّ حقلٍ بنجمةٍ ذهبيّة، وصندوقٌ أبيضُ بحافّةٍ وردية، وأيقونةٌ
  // في طرفه. **والحقولُ فارغةٌ لا أمثلة فيها** — طلبُه بلفظه: «خلي الحقول
  // فارغه». وكان في «اسم المنشأة» مثالٌ رماديٌّ («قاعة التاج») يُقرأ كأنّه
  // مكتوب، فصار النصُّ الرماديُّ اسمَ الحقل نفسَه.

  static const _edge = Color(0xFFEBDACD);
  static const _icon = Color(0xFFA5806A);

  InputDecoration _box(String? hint, {Widget? end, BoxConstraints? endSize}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 16),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
    suffixIcon: end,
    suffixIconConstraints: endSize,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _edge),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _edge),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
  );

  /// وجهُ مفتاح الدولة كما في الصورة: من اليمين «+967» ثمّ العلم، فخطٌّ، فسهم.
  /// **وخطٌّ بطول الحقل** يفصله عن الرقم.
  Widget _dialFace(String? dial) => SizedBox(
    height: 50,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, color: _edge),
        const SizedBox(width: 16),
        if (dial != null) ...[
          Text(
            '+$dial',
            key: const ValueKey('dial-label'),
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 17, color: AppColors.ink),
          ),
          const SizedBox(width: 10),
          const YemenFlag(),
        ] else
          const Icon(Icons.public, key: ValueKey('dial-other-mark'), color: AppColors.ink2),
        const SizedBox(width: 14),
        Container(width: 1, height: 28, color: _edge),
        const SizedBox(width: 10),
        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent),
        const SizedBox(width: 12),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authPaper,
      appBar: AppBar(
        backgroundColor: authPaper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.accent,
        title: Text(
          tr('تقديم خدمة'),
          style: const TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<(List<Governorate>, List<ServiceCategory>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
          final (governorates, categories) = snap.data!;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                children: [
                  const _Head(),
                  const SizedBox(height: 18),

                  _Label(tr('اسم المنشأة')),
                  TextField(
                    key: const ValueKey('apply-name'),
                    controller: _name,
                    decoration: _box(
                      tr('اسم المنشأة'),
                      end: const Icon(Icons.storefront_outlined, color: _icon, size: 26),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _Label(tr('رقم التواصل')),
                  TextField(
                    key: const ValueKey('apply-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: _box(
                      '7XX XXX XXX',
                      end: DialPicker(
                        dial: _dial,
                        enabled: !_busy,
                        onChanged: (d) => setState(() => _dial = d),
                        face: _dialFace,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _Label(tr('نبذة عن الخدمة')),
                  TextField(
                    key: const ValueKey('apply-bio'),
                    controller: _bio,
                    minLines: 2,
                    maxLines: 3,
                    decoration: _box(
                      tr('عرّف العرسان بخدماتك'),
                      // الأيقونةُ في أعلى الصندوق لا في وسطه، كما في الصورة.
                      end: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.description_outlined, color: _icon, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── المحافظة ────────────────────────────────────────────
                  //
                  // **قائمةٌ منسدلةٌ لا جدارُ شرائح.** المحافظاتُ عشرون في
                  // `seed.sql`، فكانت تملأ الشاشةَ صفوفاً تُدفع بها بقيّةُ
                  // النموذج تحت الطيّة. وعنوانُها فوقها كبقيّة الحقول.
                  _Label(tr('المحافظة')),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('governorate-field'),
                    initialValue: _governorate,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent),
                    decoration: _box(null),
                    hint: Text(
                      tr('اختر محافظتك'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                    items: [
                      for (final g in governorates)
                        DropdownMenuItem<String>(
                          value: g.name,
                          child: Text(g.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _governorate = v),
                  ),
                  const SizedBox(height: 14),

                  // ── القسم ───────────────────────────────────────────────
                  //
                  // **واحدٌ لا أكثر، وقرارُ صاحب المنصّة:** القاعةُ قاعةٌ ولا
                  // تطبخ. فهو منسدلةٌ كالمحافظة تماماً.
                  _Label(tr('القسم الذي تعمل فيه')),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('category-field'),
                    initialValue: _category,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent),
                    decoration: _box(null),
                    hint: Text(
                      tr('اختر قسمك'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('apply-submit'),
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tr('إرسال الطلب'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        // طائرةُ الورق كما في الصورة: خطٌّ رفيعٌ وأنفُها إلى أعلى
                        // اليمين. **مرسومةٌ لا أيقونة:** أيقونةُ المكتبة مصمتةُ
                        // الجناح، وتنقلب في العربيّة فيصير أنفُها إلى اليسار.
                        const SizedBox(
                          key: ValueKey('apply-send-mark'),
                          width: 24,
                          height: 24,
                          child: CustomPaint(painter: _SendMark()),
                        ),
                      ],
                    ),
                  ),
                  // غصنٌ تحت الزرّ في طرف الشاشة — **تحته لا خلفه**: كان في
                  // زاوية الشاشة فاختبأ نصفُه وراء الزرّ في الشاشة القصيرة.
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Image.asset(
                            'assets/brand/apply_sprig.png',
                            key: const ValueKey('apply-sprig-corner'),
                            height: 70,
                            color: const Color(0xFFDCC1A0),
                            colorBlendMode: BlendMode.srcIn,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
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

/// عنوانُ الحقل بنجمةٍ ذهبيّة — **كلُّ حقلٍ هنا مطلوب**.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          const TextSpan(text: ' *', style: TextStyle(color: authGoldEdge)),
        ],
      ),
      style: const TextStyle(color: AppColors.accent, fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

/// بطاقةُ الرأس: «سجّل منشأتك» وسطرُها، ورسمُ متجرٍ بزائدٍ ذهبيّة، وغصنٌ
/// خلفه — **مقصوصٌ من صورة صاحب المنصّة** (`apply_sprig.png`).
class _Head extends StatelessWidget {
  const _Head();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('apply-head'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEFDDD0)),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [Color(0xFFFFFBF7), Color(0xFFFAF0E8)],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('سجّل منشأتك'),
                  style: const TextStyle(color: AppColors.ink, fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                // **سطرٌ واحدٌ كما في الصورة** — يُصغَّر في الشاشة الضيّقة ولا
                // يُكسر ولا يُقصّ.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr('أكمل بيانات منشأتك وأرسل الطلب للمراجعة'),
                    key: const ValueKey('apply-head-line'),
                    maxLines: 1,
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 118,
          height: 112,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -4,
                top: 4,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/brand/apply_sprig.png',
                    key: const ValueKey('apply-sprig'),
                    height: 108,
                    color: const Color(0xFFD9BC97),
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const Positioned(
                right: 16,
                bottom: 20,
                child: _StorePlus(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// متجرٌ نبيذيٌّ بدائرةٍ ذهبيّةٍ فيها «+» — **مقصوصٌ من صورة صاحب المنصّة**
/// بألوانه (`apply_store.png`)، لا أيقونةٌ تشبهه: أيقونةُ «المتجر» في المكتبة
/// مظلّتُها مصمتةٌ ثقيلة، ورسمُه خطوطٌ ومظلّةٌ مخطّطة.
class _StorePlus extends StatelessWidget {
  const _StorePlus();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/brand/apply_store.png',
      key: const ValueKey('apply-store'),
      width: 68,
      errorBuilder: (_, _, _) => const Icon(Icons.storefront_outlined, size: 52, color: AppColors.accent),
    ),
  );
}

/// طائرةُ الورق في زرّ «إرسال الطلب» — على شبكةٍ ‎٢٤×٢٤‎ كخطوط صورته.
class _SendMark extends CustomPainter {
  const _SendMark();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final wing = Path()
      ..moveTo(21.5 * k, 2.5 * k) // الأنف
      ..lineTo(2.5 * k, 9 * k)
      ..lineTo(10.6 * k, 13.4 * k)
      ..lineTo(15 * k, 21.5 * k)
      ..close();
    canvas.drawPath(wing, pen);
    canvas.drawLine(Offset(21.5 * k, 2.5 * k), Offset(10.6 * k, 13.4 * k), pen);
  }

  @override
  bool shouldRepaint(_SendMark old) => false;
}
