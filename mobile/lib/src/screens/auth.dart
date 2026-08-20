import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final Session session;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;
  String? _note;

  /// البريد الذي أُنشئ له حساب وينتظر رمزه. وجودُه يقلب الشاشة إلى خطوة الرمز.
  String? _pendingEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mail = _email.text.trim();
    if (mail.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'اكتب البريد وكلمة المرور.');
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
            _note = 'أرسلنا رمزاً إلى $mail — اكتبه هنا.';
          });
        }
      } else {
        await widget.session.signIn(mail, _password.text);
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
      setState(() => _error = 'اكتب الرمز الواصل إلى بريدك.');
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
      if (mounted) setState(() => _note = 'أُرسل رمزٌ جديد. تحقّق من «المهملات» إن تأخّر.');
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// خطوة الرمز: تحلّ محلّ حقلي البريد وكلمة المرور بعد إنشاء الحساب.
  Widget _codeCard() {
    return AppCard(
      children: [
        Text(
          'أرسلنا رمزاً إلى $_pendingEmail. اكتبه هنا لتفعيل حسابك.',
          style: const TextStyle(height: 1.7),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(labelText: 'رمز التفعيل', hintText: '------'),
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
              : const Text('تفعيل الحساب'),
        ),
        TextButton(onPressed: _busy ? null : _resend, child: const Text('لم يصلني — أعد الإرسال')),
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
          child: const Text('بريدي خطأ — ارجع'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // أيقونة لا إيموجي: «💍» يحتاج خطّ رموزٍ ملوّناً لا تحمله كل
                  // الأجهزة ولا يحمله الويب، فيظهر مربّعاً فارغاً في أوّل ما
                  // يراه المستخدم من التطبيق.
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.celebration_outlined,
                      size: 30,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'فرحتي',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(
                    _pendingEmail != null
                        ? 'خطوة أخيرة — أكّد بريدك'
                        : _signUp
                        ? 'أنشئ حسابك لتبدأ تجهيز عرسك'
                        : 'سجّل الدخول لمتابعة حجوزاتك',
                  ),
                  const SizedBox(height: Space.xl),
                  if (_pendingEmail != null)
                    _codeCard()
                  else
                    AppCard(
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          // البريد لاتيني: يُترك من اليسار وإلا تبعثرت رموزه.
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            hintText: 'you@example.com',
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            hintText: '••••••••',
                            helperText: _signUp ? 'ثمانية أحرف فأكثر.' : null,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: Space.md),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.critical, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: Space.lg),
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
                              : Text(_signUp ? 'إنشاء الحساب' : 'دخول'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                          child: Text(
                            _signUp ? 'عندي حساب — سجّل الدخول' : 'ما عندي حساب — أنشئ واحداً',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: Space.lg),
                  const Text(
                    'تبدأ عميلاً، وإن أردت تقديم خدمة تطلبها من شاشة حسابك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
