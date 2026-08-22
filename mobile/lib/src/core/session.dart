import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../data/api.dart';
import 'push.dart';
import '../data/supabase.dart';

/// حالة الحساب والدور.
///
/// كل من يسجّل يبدأ **عميلاً**. ملف مقدّم الخدمة إضافةٌ لاحقة تُطلب من شاشة
/// الحساب، والدور بعدها اختيارُ عرضٍ يُبدَّل متى شاء — الشخص نفسه قد يحجز لعرس
/// أخيه ويبيع خدمة التصوير، فحبسه في أحد الطرفين يُلزمه بحسابين.
class Session extends ChangeNotifier {
  String? userId;
  String email = '';
  String? appUserId;
  String? providerId;
  bool asProvider = false;
  bool loading = true;

  /// عطبٌ منع قراءة هوية المستخدم من القاعدة — لا انعدامَ ملفٍ.
  ///
  /// الفرق جوهري: من لا ملف له يُساق إلى شاشة الإكمال وهذا صواب، ومن تعذّرت
  /// قراءته لعطبٍ في القاعدة لا يُساق إلى شيء بل يُقال له ما العطب.
  String? identityError;

  bool get signedIn => userId != null;
  bool get needsProfile => userId != null && appUserId == null;
  bool get hasProviderProfile => providerId != null;

  Future<void> boot() async {
    if (!isSupabaseConfigured) {
      // الوضع التجريبي: هوية محلّية بلا خادم، فتُتصفَّح الشاشات كلها.
      userId = 'demo-user';
      email = 'demo@example.com';
      appUserId = 'demo-user';
      providerId = await Api.myProviderId('demo-user');
      loading = false;
      notifyListeners();
      return;
    }

    db.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (session == null) {
        userId = null;
        email = '';
        appUserId = null;
        providerId = null;
        asProvider = false;
        loading = false;
        notifyListeners();
      } else {
        userId = session.user.id;
        email = session.user.email ?? '';
        refreshIdentity();
      }
    });

    final current = db.auth.currentSession;
    if (current == null) {
      loading = false;
      notifyListeners();
    } else {
      userId = current.user.id;
      email = current.user.email ?? '';
      await refreshIdentity();
    }
  }

  Future<void> refreshIdentity() async {
    loading = true;
    identityError = null;
    notifyListeners();
    try {
      appUserId = await Api.myAppUserId();
      providerId = appUserId == null ? null : await Api.myProviderId(appUserId!);
    } catch (e) {
      // لا يُبتلع. `maybeSingle` تُعيد null حين لا صفّ ولا ترمي، فكلّ ما يصل
      // هنا عطبٌ حقيقي: جدولٌ غير موجود، أو مخطّطٌ لم يُطبَّق على المشروع.
      // وابتلاعه كان يجعل ذلك يبدو «مستخدماً بلا ملف»، فيُساق إلى شاشة
      // الإكمال ليصطدم بالجدار نفسه من حيث لا يعرف سببه.
      identityError = messageOf(e);
      appUserId = null;
      providerId = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> signIn(String mail, String password) async {
    if (!isSupabaseConfigured) {
      if (password.length < 4) throw 'كلمة المرور قصيرة جداً (4 أحرف على الأقل).';
      userId = 'demo-user';
      email = mail;
      appUserId = 'demo-user';
      notifyListeners();
      return;
    }
    await db.auth.signInWithPassword(email: mail, password: password);
  }

  /// يُنشئ الحساب، ويُعيد `true` إن بقي بانتظار رمز التأكيد.
  ///
  /// التأكيد برمزٍ يُكتب لا برابطٍ يُفتح: رابط Supabase يقصد `Site URL`، وهو
  /// `localhost` افتراضاً — فيفتحه صاحب الجوال فيقول متصفّحه «رفض الاتصال»،
  /// إذ لا خادم على جواله بهذا العنوان. والرمز لا يحتاج عنواناً أصلاً.
  Future<bool> signUp(String mail, String password) async {
    if (!isSupabaseConfigured) {
      if (password.length < 8) throw 'كلمة المرور قصيرة جداً (8 أحرف على الأقل).';
      userId = 'demo-user';
      email = mail;
      appUserId = 'demo-user';
      notifyListeners();
      return false;
    }
    final res = await db.auth.signUp(email: mail, password: password);
    return res.session == null;
  }

  /// يؤكّد الحساب بالرمز الواصل إلى البريد. نجاحُه يفتح الجلسة من فوره.
  Future<void> confirmSignUp(String mail, String code) async {
    if (!isSupabaseConfigured) return;
    await db.auth.verifyOTP(type: OtpType.signup, email: mail, token: code);
  }

  Future<void> resendSignUpCode(String mail) async {
    if (!isSupabaseConfigured) return;
    await db.auth.resend(type: OtpType.signup, email: mail);
  }

  Future<void> signOut() async {
    // نسيانُ رمز الجهاز **قبل** إغلاق الجلسة: الدالّة في القاعدة تشترط أن
    // يكون الرمز لصاحبه الحالي، وبعد الخروج لا صاحب له.
    await Push.stop();
    if (isSupabaseConfigured) await db.auth.signOut();
    userId = null;
    email = '';
    appUserId = null;
    providerId = null;
    asProvider = false;
    notifyListeners();
  }

  void switchTo({required bool provider}) {
    asProvider = provider;
    notifyListeners();
  }
}
