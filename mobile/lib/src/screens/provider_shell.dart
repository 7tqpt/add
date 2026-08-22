import 'package:flutter/material.dart';

import '../core/session.dart';
import '../data/api.dart';
import '../ui/kit.dart';
import 'conversations.dart';
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

  @override
  void initState() {
    super.initState();
    _countUnread();
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

  Future<void> _openChats() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConversationsScreen()),
    );
    if (mounted) _countUnread();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['الطلبات', 'خدماتي', 'ملفي'];
    final pages = [
      RequestsScreen(session: widget.session),
      ServicesScreen(session: widget.session),
      ProviderProfileScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [ChatIconButton(unread: _unread, onTap: _openChats)],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'خدماتي'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'ملفي'),
        ],
      ),
    );
  }
}
