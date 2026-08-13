import 'package:flutter/foundation.dart';

import '../data/api.dart';
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
    notifyListeners();
    try {
      appUserId = await Api.myAppUserId();
      providerId = appUserId == null ? null : await Api.myProviderId(appUserId!);
    } catch (_) {
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

  Future<void> signUp(String mail, String password) async {
    if (!isSupabaseConfigured) {
      if (password.length < 8) throw 'كلمة المرور قصيرة جداً (8 أحرف على الأقل).';
      userId = 'demo-user';
      email = mail;
      appUserId = 'demo-user';
      notifyListeners();
      return;
    }
    final res = await db.auth.signUp(email: mail, password: password);
    if (res.session == null) {
      throw 'أُنشئ حسابك — افتح رسالة التأكيد في بريدك ثم سجّل الدخول.';
    }
  }

  Future<void> signOut() async {
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
