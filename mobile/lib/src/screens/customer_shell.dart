import 'package:flutter/material.dart';

import '../ui/kit.dart';

import '../core/session.dart';
import 'account.dart';
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

  void _goTo(int i) => setState(() => _index = i);

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
      appBar: AppBar(title: Text(titles[_index])),
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
