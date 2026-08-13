import 'package:flutter/material.dart';

import '../core/session.dart';
import 'requests.dart';
import 'provider_profile.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.session});
  final Session session;
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['الطلبات', 'ملفي'];
    final pages = [
      RequestsScreen(session: widget.session),
      ProviderProfileScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'ملفي'),
        ],
      ),
    );
  }
}
