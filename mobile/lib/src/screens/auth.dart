import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
import '../ui/auth_frame.dart';
import '../ui/kit.dart';
import 'recover_password.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session, this.startOnSignUp = false});
  final Session session;

  /// تُفتح على «إنشاء حساب» لا على «دخول».
  ///
  /// من جاء من شاشة الاختيار اختار دورَه للتوّ — فهو مستخدمٌ جديد بلا شكّ،
  /// وفتحُ شاشة الدخول في وجهه يجعله يبحث عن الزرّ الذي يقلبها.
  final bool startOnSignUp;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _confirmPassword = TextEditingController();
  late bool _signUp = widget.startOnSignUp;
  bool _busy = false;

  /// مربّعُ «تذكّرني» — **مرفوعٌ ابتداءً**، وهو ما يفعله التطبيقُ اليوم.
  bool _remember = true;

  String? _error;
  String? _note;

  /// البريد الذي أُنشئ له حساب وينتظر رمزه. وجودُه يقلب الشاشة إلى خطوة الرمز.
  String? _pendingEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = _email.text.trim();
    if (mail.isEmpty || _password.text.isEmpty) {
      setState(() => _error = tr('اكتب البريد وكلمة المرور.'));
      return;
    }
    // **وتُقارَن الكلمتان قبل أن يُنادى الخادم** — وفي الإنشاء وحدَه.
    //
    // حرفٌ زائدٌ هنا يُنشئ الحسابَ فعلاً بكلمةٍ لا يعرفها صاحبُها، وينجح
    // الدخولُ في حينه لأنّ الجلسةَ تُفتح من التسجيل نفسِه — فلا يظهر
    // الخطأُ إلّا يومَ يخرج فلا يعود.
    if (_signUp && _confirmPassword.text != _password.text) {
      setState(() => _error = tr('الكلمتان غير متطابقتين.'));
      return;
    }
    setState(() {
      _error = null;
      _note = null;
      _busy = true;
    });
    try {
      if (_signUp) {
        final needsCode = await widget.session.signUp(mail, _password.text);
        if (needsCode && mounted) {
          setState(() {
            _pendingEmail = mail;
            _note = trf('أرسلنا رمزاً إلى {0} — اكتبه هنا.', [mail]);
          });
        }
      } else {
        await widget.session.signIn(mail, _password.text, remember: _remember);
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = tr('اكتب الرمز الواصل إلى بريدك.'));
      return;
    }
    setState(() {
      _error = null;
      _note = null;
      _busy = true;
    });
    try {
      // نجاحُه يفتح الجلسة، فتنتقل الشاشة وحدها عبر مستمع تغيّر الحالة.
      await widget.session.confirmSignUp(_pendingEmail!, code);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _note = null;
      _busy = true;
    });
    try {
      await widget.session.resendSignUpCode(_pendingEmail!);
      if (mounted) setState(() => _note = tr('أُرسل رمزٌ جديد. تحقّق من «المهملات» إن تأخّر.'));
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// يفتح شاشةَ الاستعادة — **ولا يرسل شيئاً**.
  ///
  /// وكان يرسل: يقرأ حقلَ البريد في النموذج ويطلب الرمزَ فوراً. ومن نسي
  /// كلمتَه لم يأتِ ليملأ النموذج، فيضغطها على حقلٍ فارغٍ فيرتدّ عليه أمرٌ
  /// لا شرح: «اكتب بريدك أوّلاً.» — لا يقول أين، ولا يُبرز الحقل، ولا يضع
  /// فيه المؤشّر.
  ///
  /// وما كُتب في الحقل يُبذَر في الشاشة الجديدة: من كتبه لا يكتبه مرّتين.
  void _openRecover() =>
      openRecoverPassword(context, session: widget.session, seedEmail: _email.text.trim());

  /// خطوة الرمز: تحلّ محلّ حقلي البريد وكلمة المرور بعد إنشاء الحساب.
  ///
  /// **وفي البطاقة مباشرةً لا في بطاقةٍ ثانية.** بقيت هذه مرّةً في `AppCard`
  /// داخلَ الورقة البيضاء — صندوقٌ في صندوق. وأخرجه صاحبُ المنصّة بسؤالٍ
  /// قبل الدمج.
  List<Widget> _codeStep() {
    return [
      Text(
        trf('أرسلنا رمزاً إلى {0}. اكتبه هنا لتفعيل حسابك.', ['$_pendingEmail']),
        style: const TextStyle(height: 1.7),
      ),
      const SizedBox(height: Space.md),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 8),
        // **ورمزُ الرسالة يُلتقط من شريط الإشعارات.** بلا هذا يحفظه
        // صاحبُه في رأسه ويعود ليكتبه — وستُّ خاناتٍ تُنسى بين الشاشتين.
        autofillHints: const [AutofillHints.oneTimeCode],
        decoration: authInput(tr('رمز التفعيل'), Icons.pin_outlined, hint: '------'),
      ),
      if (_note != null) ...[
        const SizedBox(height: Space.sm),
        Text(_note!, style: const TextStyle(color: AppColors.good, fontSize: 13, height: 1.6)),
      ],
      if (_error != null) ...[
        const SizedBox(height: Space.md),
        Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
      ],
      const SizedBox(height: Space.lg),
      FilledButton(
        style: authPrimaryStyle,
        onPressed: _busy ? null : _confirm,
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
              )
            : Text(tr('تفعيل الحساب')),
      ),
      TextButton(onPressed: _busy ? null : _resend, child: Text(tr('لم يصلني — أعد الإرسال'))),
      const SizedBox(height: Space.sm),
      OutlinedButton(
        key: const ValueKey('back-from-code'),
        style: authOutlinedStyle,
        // مخرجٌ ممّن أخطأ بريده: بدونه يُحبس في شاشةٍ تنتظر رمزاً لن يأتي.
        // **وزرٌّ محاطٌ لا سطرٌ رفيع** — كنظيره في وجه الدخول.
        onPressed: _busy
            ? null
            : () => setState(() {
                _pendingEmail = null;
                _code.clear();
                _error = null;
                _note = null;
              }),
        child: Text(tr('بريدي خطأ — ارجع')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // ── على تصميم صاحب المنصّة ─────────────────────────────────────────────
    //
    // رأسٌ نبيذيٌّ بقوسٍ وورد، وبطاقةٌ عائمةٌ على حرير — انظر `AuthFrame`.
    // وكان رأساً أحمرَ فيه أيقونةُ التطبيق وورقةً بيضاءَ تملأ ما تحته.
    return AuthFrame(
      crest: const AuthCrest(),
      children: [
        AuthHeading(
          _pendingEmail != null
              ? tr('خطوة أخيرة — أكّد بريدك')
              : _signUp
              ? tr('إنشاء حساب')
              : tr('دخول الحساب'),
          sub: _pendingEmail != null
              ? null
              : _signUp
              ? tr('بداية فرحتك من هنا')
              : tr('أهلاً بعودتك'),
        ),
        if (_pendingEmail != null) ..._codeStep() else ..._form(),
        const SizedBox(height: Space.lg),
        Text(
          tr('تبدأ عميلاً، وإن أردت تقديم خدمة تطلبها من شاشة حسابك.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
        ),
      ],
    );
  }

  /// نموذجُ الدخول أو الإنشاء — **في البطاقة مباشرةً لا في بطاقةٍ ثانية**.
  ///
  /// بطاقةٌ بيضاءُ داخلَ بطاقةٍ بيضاءَ إطارٌ بلا معنى.
  List<Widget> _form() => [
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      // البريد لاتيني: يُترك من اليسار وإلا تبعثرت رموزه.
      textDirection: TextDirection.ltr,
      // **ويعرض الجوّالُ ما حفظه.** بلا `autofillHints` لا يقترح شيئاً،
      // فيُكتب البريدُ حرفاً حرفاً في كلّ دخول — ومن يكتب بيده يخطئ ويترك.
      autofillHints: const [AutofillHints.email],
      // **ولا مثالَ داخل الحقل.** كان فيه `you@example.com` — حروفٌ
      // لاتينيّةٌ باهتةٌ في شاشةٍ عربيّةٍ كلُّها، تُقرأ لأوّل وهلةٍ نصّاً
      // مكتوباً فعلاً فيمسحه صاحبُها قبل أن يكتب.
      decoration: authInput(tr('البريد الإلكتروني'), Icons.mail_outline),
    ),
    const SizedBox(height: 14),
    SecretField(
      controller: _password,
      label: tr('كلمة المرور'),
      helper: _signUp ? tr('ثمانية أحرف فأكثر.') : null,
      // **والجديدةُ تُعرض على مدير كلمات المرور ليحفظها**، والقديمةُ
      // تُملأ منه. وهما نيّتان مختلفتان فلا يصحّ خلطُهما.
      autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
    ),

    // ── التأكيدُ في وجه الإنشاء وحدَه ─────────────────────────────────
    //
    // **ومن يدخل لا يُسأل مرّتين:** كلمتُه معروفةٌ عنده، وخطؤه يُردّ في
    // اللحظة بـ«بيانات الدخول غير صحيحة» فيعيد.
    //
    // **وأمّا المُنشئ فخطؤه لا يُردّ عليه أبداً.** يُكتب الحرفُ الزائدُ
    // فيُحفظ، وينجح الحساب، ويدخل — ثمّ يخرج بعد شهرٍ فلا يعود. ويذهب
    // إلى «نسيت كلمة المرور» ليصلح خطأً وقع أوّلَ يوم.
    if (_signUp) ...[
      const SizedBox(height: 10),
      SecretField(
        fieldKey: const ValueKey('signup-confirm-password'),
        controller: _confirmPassword,
        label: tr('أعِد كتابة كلمة المرور'),
        autofillHints: const [AutofillHints.newPassword],
      ),
    ],

    // ── صفُّ «نسيت» و«تذكّرني» — في وجه الدخول وحدَه ─────────────────
    //
    // من يُنشئ حساباً جديداً لا كلمةَ له تُنسى، ولا جلسةَ سابقةً تُذكر.
    if (!_signUp)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // **`Expanded` لا `Flexible` بجوار `Spacer`:** ذاك يقسم الفراغَ
            // نصفين فانكسر «نسيت كلمة المرور؟» سطرين في أوّل لقطة.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('forgot-password'),
                  onPressed: _busy ? null : _openRecover,
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: Text(
                    tr('نسيت كلمة المرور؟'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Text(tr('تذكّرني'), style: const TextStyle(fontSize: 14, color: AppColors.ink2)),
            Checkbox(
              key: const ValueKey('remember-me'),
              value: _remember,
              activeColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: _busy ? null : (v) => setState(() => _remember = v ?? true),
            ),
          ],
        ),
      )
    else
      const SizedBox(height: 18),

    if (_error != null) ...[
      const SizedBox(height: Space.sm),
      Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
      const SizedBox(height: Space.sm),
    ],

    FilledButton(
      style: authPrimaryStyle,
      onPressed: _busy ? null : _submit,
      child: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
            )
          : Text(_signUp ? tr('إنشاء الحساب') : tr('دخول')),
    ),

    // ── البابُ إلى الوجه الآخر ────────────────────────────────────────
    //
    // **وزرٌّ محاطٌ لا سطرٌ صغير.** من ليس له حسابٌ يقف عند شاشة دخولٍ
    // لا يجد فيها بابَه، وسطرٌ رفيعٌ في القاع لا يُرى.
    const AuthRule(),
    Muted(_signUp ? tr('عندك حساب؟') : tr('ما عندك حساب؟'), size: 14),
    const SizedBox(height: Space.sm),
    OutlinedButton(
      key: const ValueKey('switch-face'),
      style: authOutlinedStyle,
      onPressed: _busy
          ? null
          : () => setState(() {
              _signUp = !_signUp;
              _error = null;
              // **والتأكيدُ يُمسح مع قلب الوجه.** حقلٌ يغيب عن العين ويبقى
              // فيه ما كُتب يُقارَن بكلمةٍ جديدةٍ فيردّ «غير متطابقتين»
              // على شيءٍ لا يراه صاحبُه.
              _confirmPassword.clear();
            }),
      child: Text(_signUp ? tr('دخول') : tr('إنشاء حساب')),
    ),
  ];
}
