import 'package:flutter/material.dart';

import '../core/push.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../ui/alert_banner.dart';
import '../ui/kit.dart';
import '../data/models.dart';
import 'chat.dart';
import 'conversations.dart';
import 'notifications.dart';
import 'availability.dart';
import 'requests.dart';
import 'services.dart';
import 'provider_profile.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.session});
  final Session session;
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;
  int _unread = 0;
  int _alerts = 0;

  @override
  void initState() {
    super.initState();
    _countUnread();
    _countAlerts();
    Push.start(onOpened: (data) => _openFrom(data));
  }

  /// صاحبُ القاعة أحوجُ إلى هذه الحبّة من العميل: العميل يفتح التطبيق ليسأل،
  /// وهذا يفتحه ليعمل — فرسالةٌ بلا علامةٍ ظاهرة تبقى بلا ردٍّ يوماً كاملاً.
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
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NotificationsScreen(onOpen: _followUp)));
    if (!mounted) return;
    _countAlerts();
    _countUnread();
  }

  /// «وصلك طلب حجز جديد» يُفتح على تبويب الطلبات — وهو أوّل تبويباته.
  ///
  /// وطريقٌ واحد للصندوق ولشريط النظام: الحمولة واحدة، ولو كُتب لكلٍّ مسارٌ
  /// لافترقا عند أوّل نوعٍ يُضاف.
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
      } catch (_) {}
      return;
    }
    if (data['booking_id'] != null) {
      if (popFrom != null && popFrom.mounted) Navigator.of(popFrom).pop();
      setState(() => _index = 0);
    }
  }

  void _followUp(BuildContext context, AppNotification n) => _openFrom(n.data, popFrom: context);

  Future<void> _openChats() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
    if (mounted) _countUnread();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['الطلبات', 'تقويمي', 'خدماتي', 'ملفي'];
    final pages = [
      RequestsScreen(session: widget.session),
      AvailabilityScreen(session: widget.session),
      ServicesScreen(session: widget.session),
      ProviderProfileScreen(session: widget.session),
    ];

    return Scaffold(
      // الشريط العلوي في `Stack` لا في خانة `appBar`: خانة Scaffold تحجز
      // ارتفاعها وتدفع المحتوى تحتها، فلا يمرّ شيءٌ خلف الزجاج ولا يجد
      // التمويهُ ما يموّهه. وهنا يطفو فوقه كما يطفو الشريط السفلي.
      body: AlertBanner(
        // الحمولةُ نفسها التي يفتح بها إشعارُ شريط النظام: طريقٌ واحد لِما
        // يقع أمام المستخدم ولِما يصله وهو خارج التطبيق، فلا يفترقان عند
        // أوّل نوعٍ يُضاف.
        onOpen: (data) {
          _openFrom(data);
          _countAlerts();
        },
        child: Stack(
          children: [
            pages[_index],
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GlassHeader(
                title: titles[_index],
                actions: [
                  ChatIconButton(unread: _unread, onTap: _openChats),
                  BellIconButton(unread: _alerts, onTap: _openAlerts),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'تقويمي'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'خدماتي'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'ملفي'),
        ],
      ),
    );
  }
}
