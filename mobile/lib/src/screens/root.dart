import 'package:flutter/material.dart';

import '../core/session.dart';
import '../ui/kit.dart';
import 'auth.dart';
import 'onboarding.dart';
import 'customer_shell.dart';
import 'provider_shell.dart';

/// بوّابة الإقلاع: جلسة، ثم ملف، ثم دور.
///
/// الترتيب مقصود — من لا جلسة له لا معنى لسؤاله عن دوره، ومن لا ملف له لا
/// يستطيع الحجز ولو كان مسجَّل الدخول.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loading) {
          return const Scaffold(body: LoadingBlock(label: 'جارٍ التحقق…'));
        }
        if (!session.signedIn) return AuthScreen(session: session);
        if (session.needsProfile) return OnboardingScreen(session: session);
        return session.asProvider
            ? ProviderShell(session: session)
            : CustomerShell(session: session);
      },
    );
  }
}
