import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../ui/auth_frame.dart';
import '../ui/kit.dart';
import '../ui/whatsapp_mark.dart';
import 'onboarding.dart' show YemenFlag;

/// طولُ الرمز الواصل على واتساب.
///
/// **رقمٌ واحدٌ لا اثنان:** الشاهدُ (`----`) والحدُّ (`maxLength`) يُشتقّان
/// منه معاً، فلا يُبدَّل أحدُهما ويُنسى الآخر — وهو بعينه ما وقع: الشاهدُ
/// ستُّ شُرَطٍ والرمزُ أربعةُ أرقام.
///
/// **والخادمُ أوسعُ منه**: دالّةُ الحافة تقبل `^\d{4,8}$`. فهذا حدُّ الشاشة
/// لما يُرسله المُرسِلُ اليوم، لا حدُّ النظام.
const otpLength = 4;

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
    // ── على صورتي صاحب المنصّة ─────────────────────────────────────────────
    //
    // في إطار شاشات الباب (`AuthFrame`) — **وهي ثالثةُ ثلاثٍ تُرى قبل
    // التطبيق** مع الدخول والقفل، فاختلافُ واحدةٍ منها يُقرأ تطبيقاً آخر.
    // واختار في ثلاثة أسئلة: **الرقمُ كاملاً لا مخفيّاً**، و**شعارُ واتساب
    // بلونه الأخضر**، و**«رمز التأكيد» داخلَ الخانة** بلا شُرَط.
    return AuthFrame(
      compact: true,
      crowned: true,
      crest: const _Crest(),
      children: [
        const Center(child: _WhatsAppBadge()),
        const SizedBox(height: Space.md),
        AuthHeading(
          _sent ? tr('أدخل رمز التأكيد') : tr('رقمك يؤكَّد مرّةً واحدة'),
          rule: false,
        ),
        const SizedBox(height: Space.sm),
        Text(
          _sent ? tr('أرسلنا رمزاً إلى واتساب على رقمك') : tr('سنرسل رمزاً إلى واتساب لتأكيد رقمك'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.ink2, height: 1.7),
        ),
        const SizedBox(height: Space.lg),

        // **والرقمُ كاملاً لا مخفيّاً** — اختاره صاحبُ المنصّة (أ). الشاشةُ
        // وُضعت ليتأكّد صاحبُ الرقم أنّه كتبه صحيحاً، وتحتها «رقمي خطأ —
        // بدّله»؛ فخاناتٌ مخفيّةٌ تُخفي الخطأَ إن كان فيها.
        _PhoneBox(phone: _phone),

        if (_sent) ...[
          const SizedBox(height: 14),
          // **أربعُ خاناتٍ حدّاً، و«رمز التأكيد» داخلَ الخانة** — اختاره
          // صاحبُ المنصّة (أ) مكانَ الشُّرَط الأربع التي كانت فيها. والحدُّ
          // باقٍ يمنع لصقَ رقمٍ أطولَ بالخطأ.
          //
          // **والخادمُ يقبل من أربعٍ إلى ثمانٍ** (`^\d{4,8}$` في دالّة الحافة)
          // فلا يُضيَّق عليه بهذا الحدّ: لو بدّل المُرسِلُ طولَ رمزه غداً
          // لَوجب تبديلُ `otpLength` — وهو مكتوبٌ هنا كي يُعرف أين يُبدَّل.
          TextField(
            key: const ValueKey('otp-field'),
            controller: _code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLength: otpLength,
            // **ورمزُ الرسالة يُلتقط من شريط الإشعارات.**
            autofillHints: const [AutofillHints.oneTimeCode],
            // **ولا عدّادَ تحت الحقل.** «0/4» رقمٌ لا يعني لصاحبه شيئاً،
            // ويزيح السطرَ الأخضر عن موضعه.
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            style: const TextStyle(fontSize: 22, letterSpacing: 10),
            decoration: InputDecoration(
              labelText: tr('رمز التأكيد'),
              fillColor: authPaper,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: authGoldEdge, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ],
        if (_note != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            _note!,
            style: const TextStyle(color: AppColors.good, fontSize: 13, height: 1.6),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Space.md),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.6),
          ),
        ],
        const SizedBox(height: Space.lg),
        FilledButton(
          key: const ValueKey('otp-action'),
          style: authPrimaryStyle,
          onPressed: _busy ? null : (_sent ? _verify : _send),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
                )
              : _sent
              ? Text(tr('تأكيد الرقم'))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // **الأخضرُ على دائرةٍ بيضاء** — الشعارُ بلونه على
                    // النبيذيّ مباشرةً يغيم، وبالأبيض يصير غيرَ لونه.
                    Container(
                      key: const ValueKey('send-whatsapp-mark'),
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const WhatsAppMark(size: 20),
                    ),
                    const SizedBox(width: Space.sm),
                    Flexible(child: Text(tr('أرسل الرمز على واتساب'))),
                  ],
                ),
        ),
        if (_sent)
          TextButton(
            key: const ValueKey('otp-resend'),
            onPressed: _busy || _wait > 0 ? null : _send,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(
              _wait > 0 ? trf('أعد الإرسال بعد {0} ثانية', ['$_wait']) : tr('لم يصلني — أعد الإرسال'),
            ),
          ),
        const SizedBox(height: Space.sm),
        Text(
          tr('نستخدم رقمك لتأكيد حجوزاتك والتواصل معك فقط'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
        ),

        // **ومخرجان لا واحد.** من كتب رقمه خطأً يبدّله من «حسابي» — وهو خلف
        // الحاجز، فلا يصله. فيُفتح له بابُ الملفّ من هنا، وبابُ الخروج لمن
        // أراد حساباً آخر. وبلا هذين يُحبس على شاشةٍ تنتظر رمزاً لا يأتي إلى
        // رقمٍ ليس له. **وزرٌّ محاطٌ لا سطرٌ رفيع.**
        const SizedBox(height: Space.md),
        OutlinedButton(
          key: const ValueKey('otp-edit-phone'),
          style: authOutlinedStyle,
          onPressed: _busy ? null : () => _editPhone(context),
          child: Text(tr('رقمي خطأ — بدّله')),
        ),
        const SizedBox(height: Space.xs),
        TextButton(
          onPressed: _busy ? null : widget.session.signOut,
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          child: Text(
            tr('تسجيل الخروج'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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

/// ما في القوس: القلبُ و«فرحتي»، وتحتهما «تأكيد رقمك» بالأبيض.
class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('verify-crest'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.favorite_rounded, size: 30, color: AppColors.goldOnAccent),
      Text(
        tr('فرحتي'),
        style: const TextStyle(
          fontSize: 34,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.goldOnAccent,
          fontFamilyFallback: arabicFallback,
        ),
      ),
      const SizedBox(height: Space.xs),
      Text(
        tr('تأكيد رقمك'),
        style: const TextStyle(
          fontSize: 26,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ],
  );
}

/// شعارُ واتساب في دائرةٍ كريميّة، وقلبٌ ذهبيٌّ على طرفه — كصورة «أكمل ملفك».
class _WhatsAppBadge extends StatelessWidget {
  const _WhatsAppBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('whatsapp-badge'),
    width: 84,
    height: 84,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFFFF7EC),
      border: Border.all(color: authGoldLine),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentDeep.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Stack(
      alignment: Alignment.center,
      children: [
        WhatsAppMark(size: 44),
        Positioned(
          right: 12,
          bottom: 12,
          child: Icon(Icons.favorite_rounded, size: 22, color: Color(0xFFD9A94E)),
        ),
      ],
    ),
  );
}

/// الرقمُ الذي سيصله الرمز — **كاملاً**، مقسوماً ليُقرأ، وعلمُ بلده بجانبه.
class _PhoneBox extends StatelessWidget {
  const _PhoneBox({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    final shown = displayPhone(phone);
    return Container(
      key: const ValueKey('otp-phone-box'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF5EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: authGoldLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shown,
                key: const ValueKey('otp-phone'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          if (shown.startsWith('+967'))
            const YemenFlag()
          else
            const Icon(Icons.public, color: AppColors.ink2),
        ],
      ),
    );
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
      setState(
        () => _error = tr('رقم الجوال غير مكتمل. اكتبه مع مفتاح الدولة، مثل +967 7XX XXX XXX.'),
      );
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
        Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.6)),
        const SizedBox(height: Space.md),
      ],
      FilledButton(
        key: const ValueKey('phone-edit-save'),
        onPressed: _busy ? null : _save,
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
              )
            // **و«تعديل» لا «حفظ» — بطلب صاحب المنصّة نصّاً.** والمعنى أدقُّ
            // أيضاً: الرقمُ لا يستقرّ بالضغط، بل يُبدَّل ثمّ يُؤكَّد على
            // واتساب. و«حفظ» تُوهم بأنّ الأمرَ انتهى.
            : Text(tr('تعديل')),
      ),
    ],
  );
}

String _sheetMessage(Object error) =>
    error is String && error.trim().isNotEmpty ? error : tr('تعذّر حفظ الرقم. أعد المحاولة.');

/// ورقةٌ لتبديل الرقم من داخل الحاجز.
///
/// **ولا تُستعار شاشةُ «تعديل الملفّ»:** تلك تعدّل الاسمَ والصورةَ والمحافظة
/// معاً، وهي خلف الحاجز. والمطلوبُ هنا حقلٌ واحد.
Future<String?> showPhoneEditSheet(BuildContext context, {required String current}) async {
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
            decoration: InputDecoration(labelText: tr('رقم الجوال'), hintText: '+967 7XX XXX XXX'),
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
