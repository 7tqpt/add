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
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      _busy = true;
    });
    try {
      if (_signUp) {
        await widget.session.signUp(mail, _password.text);
      } else {
        await widget.session.signIn(mail, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                    'أعراس اليمن',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(_signUp ? 'أنشئ حسابك لتبدأ تجهيز عرسك' : 'سجّل الدخول لمتابعة حجوزاتك'),
                  const SizedBox(height: Space.xl),
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
