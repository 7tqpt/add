// شاشةُ القفل: أربعةُ أرقامٍ تُدخَل بلوحةٍ في الشاشة.
//
// **ولوحةٌ في الشاشة لا لوحةُ النظام.** لوحةُ النظام تفتح وتغلق وتغطّي نصفَ
// الشاشة، وأزرارُها صغيرةٌ ومتغيّرةٌ بين الأجهزة. وأربعةُ أرقامٍ بلوحةٍ
// مرسومةٍ تُدخَل بالإبهام في ثانية.
import 'package:flutter/material.dart';

import '../core/app_lock.dart';
import '../core/biometrics.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock, required this.onSignOut});

  final AppLock lock;

  /// المخرجُ لمن نسي رمزه — ولا بدّ منه.
  final Future<void> Function() onSignOut;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _busy = false;
  String? _error;

  /// أفي الجهاز بصمةٌ مسجّلةٌ **وشُغِّلت** لهذا القفل؟
  ///
  /// **وسؤالان لا واحد:** التفضيلُ في الخزنة، والحسّاسُ في الجهاز. ومن شغّلها
  /// ثمّ محا بصماتِه من إعدادات جهازه يرى زرّاً لا يفتح شيئاً — فلا يُعرض.
  bool _canBiometric = false;

  // **وكانت هنا رايةٌ «لا تُسأل مرّتين» فحُذفت.**
  //
  // كتبتُها خوفاً من أن يُعاد بناءُ الشاشة فيدور حوارُ البصمة على نفسه.
  // ثمّ كسرتُها بضابطٍ سالبٍ — نُزعت الرايةُ — **فبقيت الحزمةُ خضراء**.
  // والسببُ أنّ الطلبَ يقع في `initState` وحدَه، وهو لا يُنادى إلّا مرّةً
  // في عمر الحال مهما أُعيد البناء. فكانت حرزاً من شيءٍ لا يقع.
  //
  // وحرزٌ لا يسقط بكسره **لا يُقاس**، فلا يُعرف أحيٌّ هو أم ميّت — وبقاؤه
  // يُوهم بحمايةٍ لا وجودَ لها. فإن صار يوماً طلبٌ ثانٍ (عند العودة من
  // الخلفيّة مثلاً) عاد معه حرزُه ومعهما ضابطٌ يُسقطه.

  @override
  void initState() {
    super.initState();
    _offerBiometric();
  }

  Future<void> _offerBiometric() async {
    if (!widget.lock.biometricEnabled) return;
    final ok = await biometrics.available();
    if (!mounted || !ok) return;
    setState(() => _canBiometric = true);
    await _biometric();
  }

  /// يسأل الجهازَ البصمة — **وإخفاقُها ليس خطأً يُصرَخ به**.
  ///
  /// من ألغى الحوارَ أراد أن يكتب رمزَه، ورسالةٌ حمراءُ في وجهه تقول إنّه
  /// أخطأ شيئاً وهو لم يخطئ. فيُترك الرمزُ مفتوحاً بلا كلمة.
  Future<void> _biometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.lock.unlockWithBiometrics();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
  }

  Future<void> _push(String digit) async {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) await _submit();
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await widget.lock.unlock(_pin);
    if (!mounted) return;

    if (ok) {
      setState(() => _busy = false);
      return;
    }

    // **وبعد الحدّ يُخرَج الحساب.** عشرةُ آلاف احتمالٍ تُجرَّب في جلسةٍ
    // واحدة لولا هذا.
    if (widget.lock.exhausted) {
      await widget.lock.forget();
      await widget.onSignOut();
      return;
    }

    setState(() {
      _busy = false;
      _pin = '';
      _error = trf('رمزٌ خاطئ — بقيت {0} محاولات.', ['${widget.lock.attemptsLeft}']);
    });
  }

  Future<void> _forgot() async {
    final yes = await confirmDanger(
      context,
      title: tr('نسيتَ الرمز؟'),
      body: tr(
        'سيُغلق حسابُك على هذا الجهاز ويُزال القفل. وتدخل من جديد '
        'ببريدك وكلمة مرورك. ولا يضيع شيءٌ من حجوزاتك ولا محادثاتك — '
        'كلُّها في حسابك لا في الجهاز.',
      ),
      confirm: tr('اخرج وأعد الدخول'),
    );
    if (yes != true) return;
    await widget.lock.forget();
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    // **ورأسٌ بنسبةٍ لا برقمٍ ثابت** — كشاشة الدخول، والعلّةُ واحدة: رقمٌ
    // ثابتٌ يأكل نصفَ جوالٍ قصيرٍ فتُدفع لوحةُ الأرقام خارجَ المشهد.
    final headerHeight = (MediaQuery.sizeOf(context).height * 0.26).clamp(140.0, 230.0);

    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Column(
        children: [
          // ── الرأسُ الأحمر ───────────────────────────────────────────────
          //
          // **وهو شكلُ شاشة الدخول بعينه.** القفلُ والدخولُ الشاشتان
          // الوحيدتان اللتان تُريان قبل التطبيق، فاختلافُهما يُقرأ تطبيقين.
          // **ورمزُ القفل لا أيقونةُ التطبيق:** من رأى شاشةً حمراءَ باسم
          // «فرحتي» ظنَّها شاشةَ دخولٍ فبحث عن بريده — والقفلُ يقول بصورته
          // إنّ الحسابَ قائمٌ وإنّما البابُ مغلق.
          SizedBox(
            height: headerHeight,
            child: SafeArea(
              bottom: false,
              // **ويُصغَّر ما لا يتّسع.** رأسٌ بارتفاعٍ محدودٍ وخطُّ جهازٍ
              // مضاعَفٌ يفيض — وقد فاض باثني عشر بكسلاً أوّلَ ما وُضعت
              // الأيقونةُ مكانَ الرمز، فأمسكه اختبارُ «لا يفيض بخطّ الجهاز
              // الكبير». والتصغيرُ أصدقُ من قصّ الاسم أو حبسِ مقياس الخطّ:
              // من كبّر خطَّ جهازه كبّره ليقرأ، لا ليُقصَّ عليه.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // **وأيقونةُ التطبيق نفسُها لا رمزٌ مرسوم.** اختارها
                      // صاحبُ المنصّة وقال: «في كل مكان». وهي `app_mark.png`
                      // — النسخةُ المشحونةُ من الأيقونة، ٢٥٦ بكسلاً تكفي
                      // رأساً يُرسم في ٦٤.
                      Image.asset(
                        'assets/brand/app_mark.png',
                        width: 68,
                        height: 68,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        tr('فرحتي'),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.xl),
                  // **وعرضٌ محدود.** على لوحٍ أو جوالٍ عريضٍ جدّاً تتباعد
                  // المفاتيحُ حتى لا تُدخَل أربعةُ أرقامٍ بإبهامٍ واحد.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr('أدخل رمز القفل'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Muted(tr('أربعة أرقام'), size: 12),
                          const SizedBox(height: Space.xl),

                          // النقاطُ الأربع — تُري ما أُدخل بلا أن تُظهر الرقم.
                          PinDots(key: const ValueKey('pin-dots'), filled: _pin.length),

                          if (_error != null) ...[
                            const SizedBox(height: Space.lg),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.critical,
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                          ],

                          const SizedBox(height: Space.xl),
                          _Pad(onDigit: _push, onBack: _back, busy: _busy),

                          // **والبصمةُ بابٌ ثانٍ لا بديلٌ عن الرمز** — واللوحةُ فوقها
                          // باقيةٌ لمن أخفق حسّاسُه أو ألغى الحوار.
                          if (_canBiometric) ...[
                            const SizedBox(height: Space.lg),
                            OutlinedButton.icon(
                              key: const ValueKey('unlock-biometric'),
                              onPressed: _busy ? null : _biometric,
                              // **ورمزُ البصمة نبيذيٌّ** — اختاره صاحبُ المنصّة
                              // بالصورة. ولا يُترك للون الزرّ: `OutlinedButton` يصبغ
                              // رمزَه بلون نصّه، وهو حبرٌ داكنٌ في هذه الثيمة.
                              icon: const Icon(
                                Icons.fingerprint,
                                size: 26,
                                color: AppColors.accent,
                              ),
                              label: Text(tr('افتح بالبصمة')),
                            ),
                            const SizedBox(height: Space.sm),
                            Muted(tr('أو أدخل رمزك'), size: 12),
                          ],

                          const SizedBox(height: Space.lg),
                          TextButton(
                            key: const ValueKey('forgot-pin'),
                            onPressed: _busy ? null : _forgot,
                            child: Text(tr('نسيتُ الرمز')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// النقاطُ الأربع — تُري ما أُدخل بلا أن تُظهر الرقم.
///
/// **وواحدةٌ للشاشة وللورقة.** كانتا نسختين متطابقتين في ملفٍّ واحد، فبُدّلت
/// إحداهما مرّةً وبقيت الأخرى.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.size = 17});
  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 4; i++)
        AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          margin: EdgeInsets.symmetric(horizontal: size * 0.5),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: i < filled ? AppColors.accent : AppColors.hairline,
              width: 1.6,
            ),
          ),
        ),
    ],
  );
}

/// لوحةُ الأرقام — ثلاثةٌ في كلّ صفّ، والصفرُ وحده مع زرّ المحو.
class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onBack, required this.busy});

  final void Function(String digit) onDigit;
  final VoidCallback onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // **والمفتاحُ يكبر بكِبَر الشاشة ولا يبقى على اثنين وسبعين بكسلاً.**
    //
    // كان مقاسُه ثابتاً، فيخرج على جوالٍ عريضٍ لوحةً صغيرةً محشورةً في وسط
    // فراغٍ واسع — تُقرأ لوحةَ آلةٍ حاسبةٍ لا لوحةَ قفل. ويُقاس هنا من عرض
    // المتاح لا من عرض الشاشة، فتصحّ اللوحةُ داخل ورقةٍ سفليّةٍ ضيّقةٍ كما
    // تصحّ في شاشةٍ كاملة.
    //
    // **وسقفٌ فوقه لا يعلو:** على الجوالات العريضة والألواح يصير المفتاحُ
    // أعرضَ من الإبهام فيبعد الرقمُ عن الرقم، فتُدخَل أربعةُ أرقامٍ بحركةِ
    // يدٍ كاملةٍ لا بإبهام.
    return LayoutBuilder(
      builder: (context, box) {
        final available = box.maxWidth.isFinite ? box.maxWidth : 320.0;
        final w = (available / 3).clamp(64.0, 104.0);
        final h = w * 0.86;
        final digit = (w * 0.36).clamp(24.0, 34.0);

        Widget key(String label, {VoidCallback? onTap, Widget? icon}) => SizedBox(
          width: w,
          height: h,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('pad-$label'),
              borderRadius: BorderRadius.circular(w / 2),
              onTap: busy ? null : (onTap ?? () => onDigit(label)),
              child: Center(
                child:
                    icon ??
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: digit,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
              ),
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (final d in row) key(d)],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: w),
                key('0'),
                key(
                  'back',
                  onTap: onBack,
                  icon: Icon(Icons.backspace_outlined, size: digit * 0.82, color: AppColors.ink2),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// يضبط رمزاً جديداً: يسأله مرّتين، ويُعيد من أخطأ التأكيدَ إلى أوّل
/// الخطوتين. ويعيد `true` إن ضُبط الرمزُ فعلاً.
///
/// **وواحدةٌ في موضعين لا نسختان.** يستعملها بابُ الإجبار وشاشةُ الإعدادات
/// جميعاً — ولو نُسخت لافترقتا عند أوّل تعديل: يُصلَح خطأٌ في إحداهما ويبقى
/// في الأخرى.
///
/// **والرمزُ يُسأل مرّتين** — من ضبط رمزاً بإصبعٍ زلّ ثمّ أُقفل عليه لا
/// سبيلَ له إلّا الخروجُ من حسابه.
///
/// **ومن أخطأ في التأكيد يُعاد إلى أوّل الخطوتين لا يُطرَد.** كانت الشاشةُ
/// تُغلق وتقول «الرمزان غير متطابقين» في شريطٍ عابر، فيبحث صاحبُها عن زرّ
/// «فعّله» من جديد — وأكثرُهم لا يعيد المحاولة أصلاً.
Future<bool> setUpPin(
  BuildContext context,
  AppLock lock, {
  String? subtitle,
  void Function(String message)? onError,
}) async {
  String? note;
  while (true) {
    if (!context.mounted) return false;
    final pin = await askPin(
      context,
      title: tr('اختر رمزاً من أربعة أرقام'),
      subtitle: subtitle ?? tr('يُطلب فورَ خروجك من التطبيق'),
      step: tr('الخطوة ١ من ٢'),
      note: note,
    );
    if (pin == null || !context.mounted) return false;

    final again = await askPin(context, title: tr('أعِد الرمز للتأكيد'), step: tr('الخطوة ٢ من ٢'));
    if (again == null || !context.mounted) return false;

    if (pin != again) {
      note = tr('الرمزان لم يتطابقا. اختر رمزاً من جديد.');
      continue;
    }

    try {
      await lock.enable(pin);
      return true;
    } catch (e) {
      onError?.call(messageOf(e));
      return false;
    }
  }
}

/// يسأل عن رمزٍ رباعيٍّ في ورقةٍ سفليّة — لضبطه أو تأكيده.
///
/// ويعيد الرمزَ أو `null` إن رجع بلا إدخال.
Future<String?> askPin(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? step,
  String? note,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PinSheet(title: title, subtitle: subtitle, step: step, note: note),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title, this.subtitle, this.step, this.note});

  final String title;
  final String? subtitle;

  /// «١ من ٢» — **ومن لا يعرف كم بقي يظنّ الشاشةَ عالقةً حين تُعاد عليه.**
  final String? step;

  /// ما يُقال لمن أخطأ في المحاولة السابقة.
  final String? note;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: Tint.disc),
              ),
              child: const Icon(Icons.lock_outline, size: 22, color: AppColors.accent),
            ),
            const SizedBox(height: Space.md),
            if (widget.step != null) ...[
              Muted(widget.step!, size: 11),
              const SizedBox(height: Space.xs),
            ],
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: Space.xs),
              Muted(widget.subtitle!, size: 12),
            ],
            if (widget.note != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                widget.note!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.critical, fontSize: 12.5, height: 1.6),
              ),
            ],
            const SizedBox(height: Space.lg),
            PinDots(filled: _pin.length),
            const SizedBox(height: Space.lg),
            _Pad(
              busy: false,
              onDigit: (d) {
                if (_pin.length >= 4) return;
                setState(() => _pin += d);
                // **ويُغلق من نفسه عند الرابع.** زرُّ «تمّ» بعد أربعة أرقامٍ
                // خطوةٌ زائدةٌ لا تضيف شيئاً.
                if (_pin.length == 4) Navigator.of(context).pop(_pin);
              },
              onBack: () {
                if (_pin.isEmpty) return;
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
            ),
            const SizedBox(height: Space.sm),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('إلغاء'))),
          ],
        ),
      ),
    );
  }
}

/// **بابُ الإجبار — لا يُفتح التطبيقُ قبل ضبط القفل.**
///
/// ── وقرارٌ نُقض عمداً، فليُقرأ نقضُه ───────────────────────────────────────
///
/// في رأس `app_lock.dart` مكتوبٌ منذ كُتب: «القفلُ اختياريّ… وقفلٌ يُفرض على
/// من لا يريده عائقٌ يوميٌّ لا حماية». **وقرّر صاحبُ المنصّة أن يُفرض** على
/// العميل ومقدّم الخدمة جميعاً، وعُرضت عليه الصورةُ وثمنُها فاختار: يُفرض
/// **فورَ الدخول**، ولا يُطفأ بعدها من الإعدادات.
///
/// وثمنُه معلومٌ ومقبولٌ عنده: كلُّ فتحةٍ تُطالب برمزٍ أو بصمة.
///
/// ── ولا زرَّ «لاحقاً» ─────────────────────────────────────────────────────
///
/// **وهو الفرقُ بين الإجبار والتشجيع.** بابٌ يُتخطّى ليس باباً.
///
/// ── والمخرجُ خروجٌ لا حبس ─────────────────────────────────────────────────
///
/// من لم يُرد قفلاً لا يُترك في شاشةٍ بلا باب: يخرج من حسابه. وهذا يُبقي
/// القرارَ بيده، ويمنع أن يصير التطبيقُ سجناً لمن ندم.
class LockGateScreen extends StatefulWidget {
  const LockGateScreen({super.key, required this.lock, required this.onSignOut});

  final AppLock lock;

  /// المخرجُ لمن لم يُرد قفلاً — ولا بدّ منه.
  final Future<void> Function() onSignOut;

  @override
  State<LockGateScreen> createState() => _LockGateScreenState();
}

class _LockGateScreenState extends State<LockGateScreen> {
  bool _busy = false;

  /// أفي الجهاز حسّاسُ بصمة؟ يُسأل مرّةً ليُكتب السطرُ صادقاً.
  ///
  /// **ولا يُوعَد بما ليس في الجهاز:** من قرأ «وبصمتُك تفتحه» ولا حسّاسَ عنده
  /// ينتظر شيئاً لا يأتي.
  bool _hasSensor = false;

  @override
  void initState() {
    super.initState();
    biometrics.available().then((has) {
      if (mounted) setState(() => _hasSensor = has);
    });
  }

  Future<void> _set() async {
    setState(() => _busy = true);
    try {
      final done = await setUpPin(
        context,
        widget.lock,
        subtitle: tr('يُطلب كلّما فتحتَ التطبيق'),
        onError: (m) {
          if (mounted) showMessage(context, m);
        },
      );
      // **ولا رسالةَ نجاحٍ هنا.** البابُ يختفي ويظهر التطبيق، وهو أوضحُ من
      // شريطٍ عابر.
      if (done && mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // **والزرُّ في أسفل الشاشة، والنزولُ ممكنٌ على القصيرة.**
        //
        // **و`Spacer` وحدَها لا تكفي داخلَ ما يُمرَّر.** كتبتُها في
        // `SingleChildScrollView` مع `minHeight` فسقط البناءُ كلُّه:
        // «RenderFlex children have non-zero flex but incoming height
        // constraints are unbounded». والأدنى لا يحدّ الأعلى — والعمودُ
        // داخلَ ما يُمرَّر بلا سقف. فيُقاس سقفُ المتاح بـ`LayoutBuilder`
        // ويُفرض بـ`IntrinsicHeight`.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - Space.lg * 2),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.xl),
                    Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: Space.lg),
                    Text(
                      tr('اقفل تطبيقك قبل أن تبدأ'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: Space.sm),
                    Muted(
                      tr(
                        'في حسابك حجوزاتُك ومحادثاتُك ومبالغُك. ومن أخذ جوالك '
                        'لحظةً يراها كلَّها ما لم يكن عليه قفل.',
                      ),
                      size: 14,
                    ),
                    const SizedBox(height: Space.lg),
                    AppCard(
                      children: [
                        _GateFact(
                          icon: Icons.pin_outlined,
                          title: tr('رمزٌ من أربعة أرقام'),
                          body: tr(
                            'يُطلب كلّما فتحتَ التطبيق. ولا يُخزَّن الرمزُ '
                            'نفسُه — بل بصمةٌ منه لا تُعكس.',
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        _GateFact(
                          icon: Icons.fingerprint,
                          title: _hasSensor ? tr('وبصمتُك تفتحه أسرع') : tr('ولا بصمةَ في جهازك'),
                          body: _hasSensor
                              ? tr(
                                  'اختياريّةٌ فوق الرمز — والرمزُ باقٍ تحتها لِما '
                                  'تعذّرت البصمة.',
                                )
                              : tr('لا حسّاسَ هنا، فالرمزُ وحدَه يفتح.'),
                        ),
                        const SizedBox(height: Space.md),
                        _GateFact(
                          icon: Icons.key_outlined,
                          title: tr('ونسيتَ رمزك؟'),
                          body: tr(
                            'تخرج من حسابك وتدخل ببريدك وكلمة مرورك، ثمّ '
                            'تضبط رمزاً جديداً.',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: Space.lg),
                    FilledButton(
                      key: const ValueKey('gate-set-pin'),
                      onPressed: _busy ? null : _set,
                      child: Text(tr('اضبط الرمز الآن')),
                    ),
                    const SizedBox(height: Space.sm),
                    TextButton(
                      key: const ValueKey('gate-sign-out'),
                      onPressed: _busy ? null : () => widget.onSignOut(),
                      child: Text(tr('خروج من الحساب')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GateFact extends StatelessWidget {
  const _GateFact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // **ولا `textStyle` بلا `fontFamily`.** نمطُ النصّ المكتوبُ يدوياً
              // لا يرث عائلةَ الثيمة، فتخرج الحروفُ مربّعاتٍ بيضاء. وقد وقعت.
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Muted(body, size: 13),
            ],
          ),
        ),
      ],
    );
  }
}
