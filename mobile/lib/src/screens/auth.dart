import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/supabase.dart';
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
  void _openRecover() => openRecoverPassword(
    context,
    session: widget.session,
    seedEmail: _email.text.trim(),
  );

  /// خطوة الرمز: تحلّ محلّ حقلي البريد وكلمة المرور بعد إنشاء الحساب.
  ///
  /// **وعلى الورقة مباشرةً لا في بطاقة.** بقيت هذه في `AppCard` حين نُقل
  /// نموذجُ الدخول إلى الورقة البيضاء، فصارت بطاقةً مؤطَّرةً داخلَ ورقةٍ
  /// بيضاء — صندوقٌ في صندوق. وأخرجه صاحبُ المنصّة بسؤالٍ قبل الدمج.
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
      const SizedBox(height: Space.sm),
      OutlinedButton(
        key: const ValueKey('back-from-code'),
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
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _pendingEmail != null
                            ? tr('خطوة أخيرة — أكّد بريدك')
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
                      if (_pendingEmail != null) ..._codeStep() else ..._form(),
                      const SizedBox(height: Space.lg),
                      Text(
                        tr('تبدأ عميلاً، وإن أردت تقديم خدمة تطلبها من شاشة حسابك.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
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

    // ── التأكيدُ في وجه الإنشاء وحدَه ─────────────────────────────────
    //
    // **ومن يدخل لا يُسأل مرّتين:** كلمتُه معروفةٌ عنده، وخطؤه يُردّ في
    // اللحظة بـ«بيانات الدخول غير صحيحة» فيعيد.
    //
    // **وأمّا المُنشئ فخطؤه لا يُردّ عليه أبداً.** يُكتب الحرفُ الزائدُ
    // فيُحفظ، وينجح الحساب، ويدخل — ثمّ يخرج بعد شهرٍ فلا يعود. ويذهب
    // إلى «نسيت كلمة المرور» ليصلح خطأً وقع أوّلَ يوم.
    if (_signUp) ...[
      const SizedBox(height: Space.md),
      TextField(
        key: const ValueKey('signup-confirm-password'),
        controller: _confirmPassword,
        obscureText: true,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: tr('أعِد كتابة كلمة المرور')),
      ),
    ],

    // ── صفُّ «نسيت» و«تذكّرني» — في وجه الدخول وحدَه ─────────────────
    //
    // من يُنشئ حساباً جديداً لا كلمةَ له تُنسى، ولا جلسةَ سابقةً تُذكر.
    if (!_signUp)
      Row(
        children: [
          TextButton(
            key: const ValueKey('forgot-password'),
            onPressed: _busy ? null : _openRecover,
            child: Text(tr('نسيت كلمة المرور')),
          ),
          const Spacer(),
          Text(tr('تذكّرني'), style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          Checkbox(
            key: const ValueKey('remember-me'),
            value: _remember,
            onChanged: _busy ? null : (v) => setState(() => _remember = v ?? true),
          ),
        ],
      )
    else
      const SizedBox(height: Space.md),

    if (_error != null) ...[
      const SizedBox(height: Space.sm),
      Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
      const SizedBox(height: Space.sm),
    ],

    FilledButton(
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
    const SizedBox(height: Space.lg),
    Muted(_signUp ? tr('عندك حساب؟') : tr('ما عندك حساب؟'), size: 12),
    const SizedBox(height: Space.sm),
    OutlinedButton(
      key: const ValueKey('switch-face'),
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

