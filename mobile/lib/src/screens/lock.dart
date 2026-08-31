// شاشةُ القفل: أربعةُ أرقامٍ تُدخَل بلوحةٍ في الشاشة.
//
// **ولوحةٌ في الشاشة لا لوحةُ النظام.** لوحةُ النظام تفتح وتغلق وتغطّي نصفَ
// الشاشة، وأزرارُها صغيرةٌ ومتغيّرةٌ بين الأجهزة. وأربعةُ أرقامٍ بلوحةٍ
// مرسومةٍ تُدخَل بالإبهام في ثانية.
import 'package:flutter/material.dart';

import '../core/app_lock.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../ui/kit.dart';

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
      _error = trf('رمزٌ خاطئ — بقيت {0} محاولات.',
          ['${widget.lock.attemptsLeft}']);
    });
  }

  Future<void> _forgot() async {
    final yes = await confirmDanger(
      context,
      title: tr('نسيتَ الرمز؟'),
      body: tr('سيُغلق حسابُك على هذا الجهاز ويُزال القفل. وتدخل من جديد '
          'ببريدك وكلمة مرورك. ولا يضيع شيءٌ من حجوزاتك ولا محادثاتك — '
          'كلُّها في حسابك لا في الجهاز.'),
      confirm: tr('اخرج وأعد الدخول'),
    );
    if (yes != true) return;
    await widget.lock.forget();
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: AppColors.accent),
                const SizedBox(height: Space.md),
                Text(
                  tr('أدخل رمز القفل'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Space.xs),
                Muted(tr('أربعة أرقام'), size: 12),
                const SizedBox(height: Space.xl),

                // النقاطُ الأربع — تُري ما أُدخل بلا أن تُظهر الرقم.
                Row(
                  key: const ValueKey('pin-dots'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length
                              ? AppColors.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: i < _pin.length
                                ? AppColors.accent
                                : AppColors.hairline,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.critical, fontSize: 13, height: 1.7),
                  ),
                ],

                const SizedBox(height: Space.xl),
                _Pad(onDigit: _push, onBack: _back, busy: _busy),

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
    );
  }
}

/// لوحةُ الأرقام — ثلاثةٌ في كلّ صفّ، والصفرُ وحده مع زرّ المحو.
class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onBack, required this.busy});

  final void Function(String digit) onDigit;
  final VoidCallback onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? icon}) => SizedBox(
      width: 72,
      height: 62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('pad-$label'),
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : (onTap ?? () => onDigit(label)),
          child: Center(
            child: icon ??
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
          ),
        ),
      ),
    );

    return Column(
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
            const SizedBox(width: 72),
            key('0'),
            key('back',
                onTap: onBack,
                icon: const Icon(Icons.backspace_outlined,
                    size: 22, color: AppColors.ink2)),
          ],
        ),
      ],
    );
  }
}

/// يسأل عن رمزٍ رباعيٍّ في ورقةٍ سفليّة — لضبطه أو تأكيده.
///
/// ويعيد الرمزَ أو `null` إن رجع بلا إدخال.
Future<String?> askPin(BuildContext context, {required String title}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PinSheet(title: title),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title});
  final String title;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length
                          ? AppColors.accent
                          : AppColors.hairline,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('إلغاء')),
          ),
        ],
      ),
    );
  }
}
