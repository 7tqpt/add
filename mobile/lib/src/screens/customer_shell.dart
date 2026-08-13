import 'package:flutter/material.dart';

import '../core/session.dart';
import 'explore.dart';
import 'my_bookings.dart';
import 'plan.dart';
import 'account.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.session});
  final Session session;
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['استكشف', 'حجوزاتي', 'خطة العرس', 'حسابي'];
    final pages = [
      const ExploreScreen(),
      MyBookingsScreen(session: widget.session),
      const PlanScreen(),
      AccountScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'استكشف'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'حجوزاتي'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'خطة العرس'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
        ],
      ),
    );
  }
}
