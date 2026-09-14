// استعادةُ كلمة المرور — **شاشةٌ مستقلّةٌ تُدفع فوق الدخول**.
//
// اختارها صاحبُ المنصّة من ثلاثٍ عُرضت عليه مرسومةً قبل أن يُلمَس `lib/`:
// «(ب) شاشةٌ مستقلّة — تُدفع فوق الدخول بسهم رجوعٍ في أعلاها».
//
// ── وما كان يقع قبلها ────────────────────────────────────────────────────────
//
// «نسيت كلمة المرور» **لم تكن تفتح شيئاً**: تقرأ حقلَ البريد في نموذج الدخول
// وترسل الرمزَ فوراً. ومن نسي كلمتَه لم يأتِ ليملأ النموذج بل ليستعيدها —
// فيضغطها على حقلٍ فارغٍ فيرتدّ عليه سطرٌ أحمر: «اكتب بريدك أوّلاً.» وهو أمرٌ
// لا شرح: لا يقول أين يُكتب، ولا يُبرز الحقل، ولا يضع فيه المؤشّر.
//
// ── وثلاثُ خطواتٍ في شاشةٍ واحدة، ولذلك سببٌ لا ذوق ─────────────────────────
//
// **الرمزُ يفتح الجلسة.** `verifyOTP(type: recovery)` يسجّل الدخولَ فعلاً —
// قبل أن تُكتب الكلمةُ الجديدة بحرف. فلو كانت خطوةُ الرمز في شاشةٍ وخطوةُ
// الكلمة في أخرى لَوقع بينهما تسجيلُ دخولٍ يقلب التطبيقَ تحت قدميه.
//
// ولذلك أيضاً **يغيب سهمُ الرجوع في الخطوة الأخيرة**: من خرج هناك دخل
// بحسابه بكلمةٍ لا يعرفها — ويعود إلى الحال نفسِها عند أوّل خروج، وهكذا
// أبداً.
//
// **وحارسٌ ثالثٌ في `root.dart`:** الجذرُ يطوي كلَّ ما فوقه عند فتح الجلسة —
// وهو صوابٌ في الدخول والخروج، وعطبٌ هنا: يطوي هذه الشاشةَ بعد الرمز
// مباشرةً فيُلقى صاحبُها في التطبيق ولم يضع كلمتَه. فيُستثنى هذا الطريقُ
// باسمه، وهو مقيسٌ في `test/recover_test.dart`.
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// اسمُ الطريق — **يُقرأ في `root.dart`** فلا يُطوى مع ما يُطوى.
const recoverRouteName = 'recover-password';

/// يفتح شاشةَ الاستعادة فوق ما تحتها.
Future<void> openRecoverPassword(
  BuildContext context, {
  required Session session,
  String seedEmail = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: recoverRouteName),
      builder: (_) =>
          RecoverPasswordScreen(session: session, seedEmail: seedEmail),
    ),
  );
}

/// أين نحن من الاستعادة.
///
/// حالةٌ مسمّاة لا رايات: الراياتُ تسمح بحالٍ لا معنى لها — «تحقّق ولم
/// يُطلب» — فتُكتب شروطٌ تحرسها ثمّ تُنسى واحدة.
enum RecoverStep { email, code, password }

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({
    super.key,
    required this.session,
    this.seedEmail = '',
  });

  final Session session;

  /// ما كُتب في حقل بريد الدخول قبل الضغط.
  ///
  /// **ومن كتبه لا يُطالَب بكتابته مرّتين.** وهو الأقلّ، لكنّه يقع.
  final String seedEmail;

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  late final _email = TextEditingController(text: widget.seedEmail);
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  RecoverStep _step = RecoverStep.email;
  bool _busy = false;
  String? _error;
  String? _note;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() body) async {
    setState(() {
      _error = null;
      _note = null;
      _busy = true;
    });
    try {
      await body();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final mail = _email.text.trim();
    if (mail.isEmpty) {
      setState(() => _error = tr('اكتب بريدك أوّلاً.'));
      return;
    }
    await _guard(() async {
      await widget.session.sendPasswordReset(mail);
      if (!mounted) return;
      setState(() {
        _step = RecoverStep.code;
        // ولا يُقال «البريد غير مسجّل» ولا «مسجّل»: ذلك يجعل الشاشة باباً
        // يعرف به الغريب من له حسابٌ في المنصّة ومن لا.
        _note = trf('إن كان {0} مسجّلاً لدينا فقد وصله رمز.', [mail]);
      });
    });
  }

  Future<void> _check() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = tr('اكتب الرمز الواصل إلى بريدك.'));
      return;
    }
    await _guard(() async {
      await widget.session.verifyPasswordReset(_email.text.trim(), code);
      if (!mounted) return;
      setState(() {
        _step = RecoverStep.password;
        _note = tr('تحقّقنا من الرمز. اكتب كلمتك الجديدة الآن.');
      });
    });
  }

  Future<void> _save() async {
    // **وتُقارَن الكلمتان قبل أن يُنادى الخادم.**
    //
    // خطأٌ مطبعيٌّ واحدٌ هنا يُبدّل الكلمةَ فعلاً إلى ما لا يعرفه صاحبُها،
    // وينجح — ولا يكتشفه إلّا يومَ يخرج فلا يعود. فالمقارنةُ في الجهاز،
    // ولا يُرسَل شيءٌ قبلها.
    //
    // **وقبل قياس الطول:** من كتب كلمتين مختلفتين لم يقصد إحداهما، وقياسُ
    // طولِ ما لم يُقصَد يقول له ما لا ينفعه.
    if (_confirmPassword.text != _newPassword.text) {
      setState(() => _error = tr('الكلمتان غير متطابقتين.'));
      return;
    }
    await _guard(() async {
      await widget.session.setPassword(_newPassword.text);
      if (!mounted) return;
      // **ويُطوى ما تحتها معها.** الجلسةُ مفتوحةٌ من الرمز، وتحت هذه
      // الشاشةِ شاشةُ الدخول التي جاء منها — فطيُّ واحدةٍ يتركه في شاشة
      // دخولٍ وهو داخلٌ أصلاً. والجذرُ لم يطوِ شيئاً لأنّنا استثنيناه.
      //
      // والرسالةُ قبل الطيّ: `ScaffoldMessenger` فوق الملاحة فتبقى.
      showMessage(context, tr('حُفظت كلمتك الجديدة.'));
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  /// **وسهمُ الرجوع يغيب في الخطوة الأخيرة.**
  bool get _canLeave => _step != RecoverStep.password;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // زرُّ الرجوع في الجهاز مثلُ السهم: يُمنع حيث يُمنع.
      canPop: _canLeave,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          elevation: 0,
          automaticallyImplyLeading: _canLeave,
          title: Text(tr('استعادة كلمة المرور')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.lg, Space.xl, Space.lg, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._stepBody(),
                if (_note != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    _note!,
                    style: const TextStyle(
                        color: AppColors.good, fontSize: 13, height: 1.6),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.critical, fontSize: 13, height: 1.6),
                  ),
                ],
                const SizedBox(height: Space.lg),
                FilledButton(
                  key: const ValueKey('recover-go'),
                  onPressed: _busy ? null : _onGo,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accentInk),
                        )
                      : Text(_goLabel),
                ),
                ..._footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback get _onGo => switch (_step) {
        RecoverStep.email => _send,
        RecoverStep.code => _check,
        RecoverStep.password => _save,
      };

  String get _goLabel => switch (_step) {
        RecoverStep.email => tr('أرسل رمز الاستعادة'),
        RecoverStep.code => tr('تحقّق من الرمز'),
        RecoverStep.password => tr('حفظ الكلمة الجديدة'),
      };

  List<Widget> _stepBody() => switch (_step) {
        RecoverStep.email => [
            const Icon(Icons.lock_reset_rounded,
                size: 56, color: AppColors.accent),
            const SizedBox(height: Space.lg),
            Text(
              tr('نسيت كلمتك؟'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: Space.md),
            Muted(
              tr('اكتب بريدك الإلكترونيّ، ونرسل إليه رمزاً تستعيد به كلمتك.'),
              size: 13,
            ),
            const SizedBox(height: Space.lg),
            TextField(
              key: const ValueKey('recover-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              // **والمؤشّرُ في الحقل من أوّل لحظة** — وهو نصفُ المقصود من
              // الشاشة: من فتحها وجد لوحةَ المفاتيح على الحقل الصحيح، ولم
              // يُقَل له «اكتب بريدك» ثمّ يُترك يبحث عن موضع الكتابة.
              autofocus: true,
              // البريد لاتينيّ: يُترك من اليسار وإلّا تبعثرت رموزه.
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: tr('البريد الإلكتروني')),
            ),
          ],
        RecoverStep.code => [
            Text(
              trf('اكتب الرمز الواصل إلى {0}.', [_email.text.trim()]),
              style: const TextStyle(height: 1.7),
            ),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('recover-code'),
              controller: _code,
              keyboardType: TextInputType.number,
              autofocus: true,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(
                labelText: tr('رمز الاستعادة'),
                hintText: '------',
              ),
            ),
          ],
        RecoverStep.password => [
            Text(
              tr('اكتب كلمة المرور الجديدة لحسابك.'),
              style: const TextStyle(height: 1.7),
            ),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('recover-new-password'),
              controller: _newPassword,
              obscureText: true,
              autofocus: true,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('كلمة المرور الجديدة'),
                helperText: tr('ثمانية أحرف فأكثر.'),
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('recover-confirm-password'),
              controller: _confirmPassword,
              obscureText: true,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('أعِد كتابة الكلمة الجديدة'),
              ),
            ),
          ],
      };

  List<Widget> _footer() => switch (_step) {
        RecoverStep.email => const [],
        RecoverStep.code => [
            TextButton(
              onPressed: _busy ? null : _send,
              child: Text(tr('لم يصلني — أعد الإرسال')),
            ),
            TextButton(
              key: const ValueKey('recover-wrong-email'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _step = RecoverStep.email;
                        _code.clear();
                        _error = null;
                        _note = null;
                      }),
              child: Text(tr('بريدي خطأ — ارجع')),
            ),
          ],
        // **ولا مخرجَ هنا.** لا سهمٌ ولا زرّ: الجلسةُ مفتوحةٌ والكلمةُ لم
        // تُكتب بعد.
        RecoverStep.password => const [],
      };
}
