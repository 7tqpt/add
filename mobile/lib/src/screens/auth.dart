import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

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
  final _newPassword = TextEditingController();
  late bool _signUp = widget.startOnSignUp;
  bool _busy = false;

  /// مربّعُ «تذكّرني» — **مرفوعٌ ابتداءً**، وهو ما يفعله التطبيقُ اليوم.
  bool _remember = true;

  String? _error;
  String? _note;

  /// البريد الذي أُنشئ له حساب وينتظر رمزه. وجودُه يقلب الشاشة إلى خطوة الرمز.
  String? _pendingEmail;

  /// أين نحن من استعادة كلمة المرور. `none` تعني أننا في شاشة الدخول.
  _Recover _recover = _Recover.none;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = _email.text.trim();
    if (mail.isEmpty || _password.text.isEmpty) {
      setState(() => _error = tr('اكتب البريد وكلمة المرور.'));
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
        await widget.session.signIn(mail, _password.text,
            remember: _remember);
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

  // ----- استعادة كلمة المرور: بريد ← رمز ← كلمة جديدة -----

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

  Future<void> _askCode() async {
    final mail = _email.text.trim();
    if (mail.isEmpty) {
      setState(() => _error = tr('اكتب بريدك أوّلاً.'));
      return;
    }
    await _guard(() async {
      await widget.session.sendPasswordReset(mail);
      if (!mounted) return;
      setState(() {
        _recover = _Recover.code;
        // ولا يُقال «البريد غير مسجّل» ولا «مسجّل»: ذلك يجعل الشاشة باباً
        // يعرف به الغريب من له حسابٌ في المنصّة ومن لا.
        _note = trf('إن كان {0} مسجّلاً لدينا فقد وصله رمز.', [mail]);
      });
    });
  }

  Future<void> _checkCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = tr('اكتب الرمز الواصل إلى بريدك.'));
      return;
    }
    await _guard(() async {
      await widget.session.verifyPasswordReset(_email.text.trim(), code);
      if (!mounted) return;
      // نجاحُ الرمز يفتح جلسةً — ولذلك تُطلب الكلمة الجديدة **الآن**: لو خرج
      // من الشاشة هنا لدخل بحسابه بلا كلمةٍ يعرفها، ولعاد إلى الحال نفسها
      // عند أوّل خروج.
      setState(() {
        _recover = _Recover.password;
        _note = tr('تحقّقنا من الرمز. اكتب كلمتك الجديدة الآن.');
      });
    });
  }

  Future<void> _savePassword() async {
    await _guard(() async {
      await widget.session.setPassword(_newPassword.text);
      if (!mounted) return;
      // الجلسة مفتوحةٌ أصلاً من الرمز، فتنتقل الشاشة وحدها.
      setState(() => _recover = _Recover.none);
    });
  }

  void _leaveRecovery() => setState(() {
    _recover = _Recover.none;
    _code.clear();
    _newPassword.clear();
    _error = null;
    _note = null;
  });

  /// خطوة الرمز: تحلّ محلّ حقلي البريد وكلمة المرور بعد إنشاء الحساب.
  Widget _codeCard() {
    return AppCard(
      children: [
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
          decoration: InputDecoration(labelText: tr('رمز التفعيل'), hintText: '------'),
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
        TextButton(
          // مخرجٌ ممّن أخطأ بريده: بدونه يُحبس في شاشةٍ تنتظر رمزاً لن يأتي.
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
      ],
    );
  }

  /// خطوةُ الرمز ثم خطوةُ الكلمة الجديدة.
  Widget _recoverCard() {
    final onCode = _recover == _Recover.code;
    return AppCard(
      children: [
        Text(
          onCode
              ? trf('اكتب الرمز الواصل إلى {0}.', [_email.text.trim()])
              : tr('اكتب كلمة المرور الجديدة لحسابك.'),
          style: const TextStyle(height: 1.7),
        ),
        const SizedBox(height: Space.md),
        if (onCode)
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            decoration: InputDecoration(labelText: tr('رمز الاستعادة'), hintText: '------'),
          )
        else
          TextField(
            controller: _newPassword,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: tr('كلمة المرور الجديدة'),
              helperText: tr('ثمانية أحرف فأكثر.'),
            ),
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
          onPressed: _busy ? null : (onCode ? _checkCode : _savePassword),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentInk),
                )
              : Text(onCode ? tr('تحقّق من الرمز') : tr('حفظ الكلمة الجديدة')),
        ),
        if (onCode)
          TextButton(onPressed: _busy ? null : _askCode, child: Text(tr('لم يصلني — أعد الإرسال'))),
        TextButton(
          onPressed: _busy ? null : _leaveRecovery,
          child: Text(tr('رجوع إلى تسجيل الدخول')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // **ورأسٌ بنسبةٍ لا برقمٍ ثابت.** التصميمُ المرسَل من آيفونَ طويل،
    // ورقمٌ ثابتٌ يأكل نصفَ جوالٍ قصيرٍ فيدفع «دخول» تحت لوحة المفاتيح.
    final height = MediaQuery.sizeOf(context).height;
    final headerHeight = (height * 0.26).clamp(140.0, 230.0);

    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // أيقونة لا إيموجي: «💍» يحتاج خطّ رموزٍ ملوّناً لا
                    // تحمله كل الأجهزة، فيظهر مربّعاً فارغاً في أوّل ما يراه
                    // المستخدم من التطبيق.
                    const Icon(Icons.celebration_outlined,
                        size: 44, color: AppColors.accentInk),
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
          // ── الورقةُ البيضاء ────────────────────────────────────────────
          //
          // **وتأخذ ما بقي من الشاشة مهما طال النموذج.** خطوةُ الرمز
          // وخطوةُ الاستعادة أطولُ من الدخول، فلو كان ارتفاعُها من المحتوى
          // لَتحرّك الرأسُ بين خطوةٍ وأخرى.
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
                  padding: const EdgeInsets.fromLTRB(
                      Space.lg, Space.xl, Space.lg, Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _pendingEmail != null
                            ? tr('خطوة أخيرة — أكّد بريدك')
                            : _recover != _Recover.none
                                ? tr('استعادة كلمة المرور')
                                : _signUp
                                    ? tr('إنشاء حساب')
                                    : tr('دخول الحساب'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      if (_pendingEmail != null)
                        _codeCard()
                      else if (_recover != _Recover.none)
                        _recoverCard()
                      else
                        ..._form(),
                      const SizedBox(height: Space.lg),
                      Text(
                        tr('تبدأ عميلاً، وإن أردت تقديم خدمة تطلبها من شاشة حسابك.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نموذجُ الدخول أو الإنشاء — **على الورقة مباشرةً لا في بطاقةٍ ثانية**.
  ///
  /// بطاقةٌ بيضاءُ فوق ورقةٍ بيضاءَ إطارٌ بلا معنى.
  List<Widget> _form() => [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          // البريد لاتيني: يُترك من اليسار وإلا تبعثرت رموزه.
          textDirection: TextDirection.ltr,
          // **ولا مثالَ داخل الحقل.** كان فيه `you@example.com` — حروفٌ
          // لاتينيّةٌ باهتةٌ في شاشةٍ عربيّةٍ كلُّها، تُقرأ لأوّل وهلةٍ نصّاً
          // مكتوباً فعلاً فيمسحه صاحبُها قبل أن يكتب.
          decoration: InputDecoration(labelText: tr('البريد الإلكتروني')),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _password,
          obscureText: true,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: tr('كلمة المرور'),
            helperText: _signUp ? tr('ثمانية أحرف فأكثر.') : null,
          ),
        ),

        // ── صفُّ «نسيت» و«تذكّرني» — في وجه الدخول وحدَه ─────────────────
        //
        // من يُنشئ حساباً جديداً لا كلمةَ له تُنسى، ولا جلسةَ سابقةً تُذكر.
        if (!_signUp)
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _askCode,
                child: Text(tr('نسيت كلمة المرور')),
              ),
              const Spacer(),
              Text(tr('تذكّرني'),
                  style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
              Checkbox(
                key: const ValueKey('remember-me'),
                value: _remember,
                onChanged:
                    _busy ? null : (v) => setState(() => _remember = v ?? true),
              ),
            ],
          )
        else
          const SizedBox(height: Space.md),

        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.critical, fontSize: 13),
          ),
          const SizedBox(height: Space.sm),
        ],

        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentInk,
                  ),
                )
              : Text(_signUp ? tr('إنشاء الحساب') : tr('دخول')),
        ),

        // ── البابُ إلى الوجه الآخر ────────────────────────────────────────
        //
        // **وزرٌّ محاطٌ لا سطرٌ صغير.** من ليس له حسابٌ يقف عند شاشة دخولٍ
        // لا يجد فيها بابَه، وسطرٌ رفيعٌ في القاع لا يُرى.
        const SizedBox(height: Space.lg),
        Muted(
          _signUp ? tr('عندك حساب؟') : tr('ما عندك حساب؟'),
          size: 12,
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(
          key: const ValueKey('switch-face'),
          onPressed: _busy
              ? null
              : () => setState(() {
                    _signUp = !_signUp;
                    _error = null;
                  }),
          child: Text(_signUp ? tr('دخول') : tr('إنشاء حساب')),
        ),
      ];
}

/// أين نحن من استعادة كلمة المرور.
///
/// حالةٌ مسمّاة لا رايتان (`_asking` و`_verified`): الراياتُ تسمح بحالٍ لا
/// معنى لها — «تحقّق ولم يُطلب» — فتُكتب شروطٌ تحرسها ثم تُنسى واحدة.
enum _Recover { none, code, password }
