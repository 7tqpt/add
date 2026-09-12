import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../ui/kit.dart';

/// تأكيدُ رقم الجوال برمزٍ على واتساب — مرّةً واحدةً في عمر الحساب.
///
/// قرّر صاحبُ المنصّة أنّ من لم يؤكّد رقمه لا يرى التطبيق: الرقمُ هو ما
/// يُتواصل به في كلّ حجز، ورقمٌ مكتوبٌ بالخطأ يعني حجزاً لا يُوصَل إلى صاحبه.
///
/// ── ولا يُرسَل الرمزُ عند الفتح ─────────────────────────────────────────────
///
/// **وهذا قرارٌ لا سهو.** الحاجزُ يقف أمام صاحبه في **كلّ فتحةٍ** حتى يؤكّد،
/// فإرسالٌ تلقائيٌّ عند الفتح يعني رسالةً مدفوعةً من رصيد صاحب المنصّة في كلّ
/// مرّةٍ يُفتح فيها التطبيقُ ثمّ يُغلق. فالإرسالُ بضغطةٍ من صاحبه، وحينها
/// يكون حاضراً لقراءة ما يصله.
///
/// والشاشةُ خطوتان: طلبُ الرمز، ثمّ كتابتُه.
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key, required this.session});
  final Session session;

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _code = TextEditingController();

  /// أُرسل الرمزُ مرّةً فصارت الشاشةُ تنتظر كتابتَه.
  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _note;

  /// ثوانٍ باقيةٌ قبل أن يُتاح «أعد الإرسال».
  ///
  /// **وهي زينةٌ لا حرز.** الحدُّ الحقيقيُّ في القاعدة — واحدةٌ كلَّ دقيقةٍ
  /// وثلاثٌ في الساعةٍ وعشرٌ في اليوم — لأنّ مهلةً في الشاشة تُتجاوز بنداءٍ
  /// مباشرٍ إلى الدالّة. وهذه لتقول لصاحبها كم يبقى فلا يضغط في الفراغ.
  int _wait = 0;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _tick?.cancel();
    setState(() => _wait = seconds);
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _wait = _wait - 1);
      if (_wait <= 0) timer.cancel();
    });
  }

  String get _phone => widget.session.phoneGate.phone;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
    });
    try {
      await Api.sendPhoneOtp(_phone);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _note = tr('أرسلنا الرمز. تحقّق من واتساب.');
      });
      _startCooldown();
    } catch (e) {
      // **والنصُّ من الخادم كما هو.** دالّةُ الحافة تكتب بالعربيّة سببَ
      // الردّ — «انتظر ٤٠ ثانية» أو «رقمك مؤكَّدٌ أصلاً» — وهو أدقُّ من
      // رسالةٍ عامّةٍ تُكتب هنا بلا معرفةٍ بالسبب.
      if (mounted) setState(() => _error = _say(e, tr('تعذّر إرسال الرمز. أعد المحاولة.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// نصُّ الخادم إن أرسله، وإلّا نصٌّ مترجَمٌ يُكتب هنا.
  ///
  /// **ودالّةُ الحافة تكتب بالعربيّة سببَ الردّ** — «انتظر ٤٠ ثانية» أو
  /// «رقمك مؤكَّدٌ أصلاً» — وهو أدقُّ من رسالةٍ عامّةٍ لا تعرف السبب. وطبقةُ
  /// البيانات ترميه نصّاً، فما جاء نصّاً فهو منها.
  String _say(Object error, String fallback) =>
      error is String && error.trim().isNotEmpty ? error : fallback;

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = tr('اكتب الرمز الواصل إلى واتساب.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
    });
    try {
      final ok = await Api.verifyPhoneOtp(_phone, code);
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = tr('الرمزُ غير صحيح أو انتهت مدّته.'));
        return;
      }
      // **ولا ملاحةَ من هنا.** الحاجزُ في `RootScreen` يقرأ حالَ الجلسة،
      // فتحديثُ الهويّة يرفعه وحده ويظهر التطبيق. ودفعُ شاشةٍ من هنا يترك
      // هذه الشاشةَ تحتها في المكدّس.
      await widget.session.refreshIdentity();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _say(e, tr('تعذّر التحقّق من الرمز. أعد المحاولة.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('تأكيد رقمك'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              SectionTitle(tr('رقمك يؤكَّد مرّةً واحدة')),
              const SizedBox(height: Space.sm),
              Text(
                _sent
                    ? trf('أرسلنا رمزاً على واتساب إلى {0}. اكتبه هنا.', [_phone])
                    : trf('سنرسل رمزاً على واتساب إلى {0} لتأكيد أنّه رقمك.',
                        [_phone]),
                style: const TextStyle(height: 1.8),
              ),
              if (_sent) ...[
                const SizedBox(height: Space.lg),
                TextField(
                  key: const ValueKey('otp-field'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: tr('رمز التأكيد'),
                    hintText: '------',
                  ),
                ),
              ],
              if (_note != null) ...[
                const SizedBox(height: Space.sm),
                Text(_note!,
                    style: const TextStyle(
                        color: AppColors.good, fontSize: 13, height: 1.6)),
              ],
              if (_error != null) ...[
                const SizedBox(height: Space.md),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.critical, fontSize: 13, height: 1.6)),
              ],
              const SizedBox(height: Space.lg),
              FilledButton(
                key: const ValueKey('otp-action'),
                onPressed: _busy ? null : (_sent ? _verify : _send),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentInk),
                      )
                    : Text(_sent
                        ? tr('تأكيد الرقم')
                        : tr('أرسل الرمز على واتساب')),
              ),
              if (_sent)
                TextButton(
                  key: const ValueKey('otp-resend'),
                  onPressed: _busy || _wait > 0 ? null : _send,
                  child: Text(_wait > 0
                      ? trf('أعد الإرسال بعد {0} ثانية', ['$_wait'])
                      : tr('لم يصلني — أعد الإرسال')),
                ),
              const SizedBox(height: Space.xs),
              Muted(tr('الرقم يُستعمل لتأكيد حجوزاتك والتواصل معك، ولا يُؤكَّد مرّةً ثانية.')),
            ],
          ),
          const SizedBox(height: Space.md),
          // **ومخرجان لا واحد.** من كتب رقمه خطأً يبدّله من «حسابي» — وهو
          // خلف الحاجز، فلا يصله. فيُفتح له بابُ الملفّ من هنا، وبابُ
          // الخروج لمن أراد حساباً آخر. وبلا هذين يُحبس على شاشةٍ تنتظر
          // رمزاً لا يأتي إلى رقمٍ ليس له.
          TextButton(
            key: const ValueKey('otp-edit-phone'),
            onPressed: _busy ? null : () => _editPhone(context),
            child: Text(tr('رقمي خطأ — بدّله')),
          ),
          TextButton(
            onPressed: _busy ? null : widget.session.signOut,
            child: Text(tr('تسجيل الخروج')),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhone(BuildContext context) async {
    final changed = await showPhoneEditSheet(context, current: _phone);
    if (changed == null || !mounted) return;
    await widget.session.refreshIdentity();
    if (!mounted) return;
    setState(() {
      _sent = false;
      _code.clear();
      _error = null;
      _note = trf('صار رقمك {0}. اطلب الرمز الآن.', [changed]);
    });
  }
}

/// زرُّ حفظ الرقم — بفحصٍ ورسالةٍ في الورقة نفسِها.
class _PhoneEditButton extends StatefulWidget {
  const _PhoneEditButton({required this.controller});
  final TextEditingController controller;

  @override
  State<_PhoneEditButton> createState() => _PhoneEditButtonState();
}

class _PhoneEditButtonState extends State<_PhoneEditButton> {
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final phone = normalisePhone(widget.controller.text);
    if (phone == null) {
      setState(() => _error = tr('رقم الجوال غير مكتمل. اكتبه مع مفتاح الدولة، مثل +967 7XX XXX XXX.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.updateMyPhone(phone);
      if (mounted) Navigator.of(context).pop(phone);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _sheetMessage(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.critical, fontSize: 13, height: 1.6)),
            const SizedBox(height: Space.md),
          ],
          FilledButton(
            key: const ValueKey('phone-edit-save'),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accentInk),
                  )
                : Text(tr('حفظ')),
          ),
        ],
      );
}

String _sheetMessage(Object error) =>
    error is String && error.trim().isNotEmpty
        ? error
        : tr('تعذّر حفظ الرقم. أعد المحاولة.');

/// ورقةٌ لتبديل الرقم من داخل الحاجز.
///
/// **ولا تُستعار شاشةُ «تعديل الملفّ»:** تلك تعدّل الاسمَ والصورةَ والمحافظة
/// معاً، وهي خلف الحاجز. والمطلوبُ هنا حقلٌ واحد.
Future<String?> showPhoneEditSheet(
  BuildContext context, {
  required String current,
}) async {
  final controller = TextEditingController(text: current);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: Space.lg,
        right: Space.lg,
        top: Space.lg,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(tr('رقم الجوال')),
          const SizedBox(height: Space.md),
          TextField(
            key: const ValueKey('phone-edit-field'),
            controller: controller,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('رقم الجوال'),
              hintText: '+967 7XX XXX XXX',
            ),
          ),
          const SizedBox(height: Space.lg),
          // **ويُفحص هنا أشدَّ ما يُفحص.** من وصل إلى هذه الورقة وصلها
          // لأنّ رقمَه لم يصله رمز — فحفظُ رقمٍ ناقصٍ ثانياً يُعيده إلى
          // الحلقة نفسِها. والرسالةُ تُعرض في الورقة لا خلفها.
          _PhoneEditButton(controller: controller),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}
