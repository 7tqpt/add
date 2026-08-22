import 'package:flutter/material.dart';

import '../ui/kit.dart';

import '../core/push.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import 'account.dart';
import 'chat.dart';
import 'conversations.dart';
import 'notifications.dart';
import 'explore.dart';
import 'home.dart';
import 'my_bookings.dart';
import 'plan.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.session});
  final Session session;
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  int _unread = 0;
  int _alerts = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
    _countAlerts();
    // الدفع يبدأ من القشرة لا من الإقلاع: القشرة لا تُبنى إلّا بعد تسجيل
    // الدخول وإكمال الملف، والرمز يُنسب إلى حسابٍ فلا معنى لتسجيله قبله.
    Push.start(onOpened: (data) => _openFrom(data));
  }

  void _goTo(int i) => setState(() => _index = i);

  /// عدُّ ما لم يُقرأ في كل المحادثات.
  ///
  /// وفشلُه يمرّ صامتاً: الحبّة زينةٌ تدلّ، وسقوطُ عدّها لا يجوز أن يُظهر خطأً
  /// في شاشةٍ بقيّتُها تعمل.
  Future<void> _countUnread() async {
    try {
      final rows = await Api.myConversations();
      if (!mounted) return;
      setState(() => _unread = rows.fold<int>(0, (n, c) => n + c.unreadCount));
    } catch (_) {}
  }

  Future<void> _countAlerts() async {
    try {
      final rows = await Api.myNotifications();
      if (!mounted) return;
      setState(() => _alerts = rows.where((n) => n.isUnread).length);
    } catch (_) {}
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsScreen(onOpen: _followUp)),
    );
    if (!mounted) return;
    _countAlerts();
    _countUnread();
  }

  /// ما يفتحه الضغط على إشعار — من الصندوق أو من شريط النظام.
  ///
  /// والرسالة تُفتح على خيطها لا على قائمة المحادثات: من ضغط إشعاراً باسم
  /// «قاعة التاج» يريد ما قالته القاعة، لا قائمةً يبحث فيها عنها.
  ///
  /// والطريقان واحد لأن الحمولة واحدة: `data` نفسها في صفّ الإشعار وفي رسالة
  /// FCM. ولو كُتب لكلٍّ مسارٌ لافترقا عند أوّل نوعٍ يُضاف.
  Future<void> _openFrom(Map<String, dynamic> data, {BuildContext? popFrom}) async {
    final conversationId = data['conversation_id'] as String?;
    if (conversationId != null) {
      try {
        final rows = await Api.myConversations();
        final convo = rows.where((c) => c.id == conversationId).firstOrNull;
        if (convo == null || !mounted) return;
        await Navigator.of(popFrom ?? context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convo.id,
              otherName: convo.otherName,
              mySide: convo.mySide,
            ),
          ),
        );
      } catch (_) {
        // المحادثة قد تكون حُذفت: لا يُفتح شيء، ولا يسقط شيء.
      }
      return;
    }

    // الحجوزات والمدفوعات والتقييمات كلُّها تقع في تبويب «حجوزاتي»: تُغلق
    // شاشة الإشعارات ويُفتح التبويب — لا شاشةٌ ثالثة فوق الثانية.
    if (data['booking_id'] != null || data['payment_id'] != null) {
      if (popFrom != null && popFrom.mounted) Navigator.of(popFrom).pop();
      _goTo(1);
    }
  }

  void _followUp(BuildContext context, AppNotification n) =>
      _openFrom(n.data, popFrom: context);

  Future<void> _openChats() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConversationsScreen()),
    );
    // عند العودة: ما قُرئ هناك يجب أن يختفي من الحبّة هنا.
    if (mounted) _countUnread();
  }

  @override
  Widget build(BuildContext context) {
    // الترتيب: الرئيسية أوّلاً — وهي في العربية أقصى اليمين، أوّلُ ما يقع
    // عليه الإبهام. وحسابي آخراً: أقلُّها فتحاً وأبعدُها عن الوسط.
    final titles = ['الرئيسية', 'حجوزاتي', 'استكشف', 'خطة العرس', 'حسابي'];
    final pages = [
      HomeScreen(session: widget.session, onGoTo: _goTo),
      MyBookingsScreen(session: widget.session),
      const ExploreScreen(),
      PlanScreen(session: widget.session),
      AccountScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          ChatIconButton(unread: _unread, onTap: _openChats),
          BellIconButton(unread: _alerts, onTap: _openAlerts),
        ],
      ),
      // المحتوى يمرّ **تحت** الشريط لا فوقه: هذا ما يعطي التمويهَ ما يموّهه.
      // ولذلك تُنهي كل قائمةٍ محتواها بمسافة `glassNavSpace`، وإلا اختفت آخرُ
      // بطاقةٍ فيها خلف الزجاج.
      extendBody: true,
      body: pages[_index],
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onSelect: _goTo,
        items: const [
          GlassNavItem(label: 'الرئيسية', icon: Icons.home_outlined, activeIcon: Icons.home),
          GlassNavItem(
            label: 'حجوزاتي',
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
          ),
          GlassNavItem(label: 'استكشف', icon: Icons.search_outlined, activeIcon: Icons.search),
          GlassNavItem(
            label: 'خطة العرس',
            icon: Icons.favorite_outline,
            activeIcon: Icons.favorite,
          ),
          GlassNavItem(label: 'حسابي', icon: Icons.person_outline, activeIcon: Icons.person),
        ],
      ),
    );
  }
}
