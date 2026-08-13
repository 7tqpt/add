import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.session});
  final Session session;
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() {
    final id = widget.session.appUserId;
    return id == null ? Future.value(const []) : Api.myBookings(id);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Booking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final rows = snap.data ?? const <Booking>[];
        if (rows.isEmpty) {
          return const EmptyBlock(
            title: 'لا حجوزات بعد',
            description: 'ابدأ من «استكشف» واختر أول خدمة لعرسك.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(Space.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final b = rows[i];
              return AppCard(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          b.serviceTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      StatusBadge(
                        bookingStatusLabel(b.status),
                        color: bookingStatusColor(b.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Muted(b.providerName),
                  const SizedBox(height: Space.sm),
                  Text(
                    b.eventTime == null
                        ? formatDate(b.eventDate)
                        : '${formatDate(b.eventDate)} · ${formatTime(b.eventTime)}',
                    style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإجمالي ${formatMoney(b.totalPrice)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink),
                      ),
                      Muted(
                        b.paidAmount > 0 ? 'مدفوع ${formatMoney(b.paidAmount)}' : 'لم يُدفع بعد',
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      b.reference,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
