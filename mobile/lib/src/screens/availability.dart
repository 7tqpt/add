// تقويم مقدّم الخدمة: ما هو مشغول، وما أغلقه بنفسه.
//
// **ولماذا شاشةٌ لا قائمة:** المزوّد يسأل سؤالاً واحداً — «هل أنا فاضٍ في
// الخامس عشر؟» — والجواب في شبكة الشهر بنظرة، وفي قائمةٍ من التواريخ بقراءة.
//
// **والفرق بين لونين هنا مالٌ لا زينة:** يومٌ أغلقته القاعدة بحجزٍ مؤكّد لا
// يفتحه صاحبه (ولو فُتح لوقع عرسان في ليلة)، ويومٌ أغلقه بعذرٍ يفتحه متى شاء.
// فالشاشة تقول أيُّهما بلونه ونصّه، ولا تعرض زرّاً لا يعمل.
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../data/supabase.dart' show messageOf;
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../ui/kit.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key, required this.session});

  final Session session;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late DateTime _month;
  Future<List<DayMark>>? _future;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  void _load() {
    setState(() {
      _future = Api.myDays(_month, _lastDayOf(_month));
    });
  }

  static DateTime _lastDayOf(DateTime month) =>
      DateTime(month.year, month.month + 1, 0);

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  Future<void> _toggle(DateTime day, DayMark? mark) async {
    // يومٌ مضى لا يُعدَّل — والقاعدة ترفضه أيضاً، لكن رسالةً حمراء بعد ضغطةٍ
    // أسوأ من ضغطةٍ لا تقع.
    final today = DateTime.now();
    if (day.isBefore(DateTime(today.year, today.month, today.day))) return;

    if (mark != null && mark.byBooking) {
      showMessage(context, 'هذا اليوم محجوز: ${mark.note}');
      return;
    }

    final blocked = mark != null;
    String note = '';
    if (!blocked) {
      final typed = await _askNote(day);
      if (typed == null) return;
      note = typed;
    }

    try {
      await Api.setAvailability(day, !blocked, note: note);
      if (!mounted) return;
      setState(() => _error = null);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = messageOf(e));
    }
  }

  Future<String?> _askNote(DateTime day) async {
    final controller = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إغلاق ${formatDay(day)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Muted('لن يستطيع أحد أن يحجزك في هذا اليوم. والسبب لك وحدك — لا يراه العميل.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'السبب (اختياري)',
                hintText: 'سفر، مناسبة عائلية، صيانة…',
              ),
              onSubmitted: (v) => Navigator.of(sheetContext).pop(v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(controller.text),
              child: const Text('أغلق اليوم'),
            ),
          ],
        ),
      ),
    );
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
        children: [
          _MonthBar(month: _month, onShift: _shift),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBlock(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          FutureBuilder<List<DayMark>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingBlock();
              }
              if (snapshot.hasError) {
                return ErrorBlock(message: messageOf(snapshot.error!), onRetry: _load);
              }
              final marks = snapshot.data ?? const <DayMark>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Grid(month: _month, marks: marks, onTap: _toggle),
                  const SizedBox(height: 16),
                  const _Legend(),
                  const SizedBox(height: 16),
                  _Closed(marks: marks, onTap: _toggle),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.onShift});

  final DateTime month;
  final void Function(int months) onShift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'الشهر السابق',
        ),
        Expanded(
          child: Text(
            formatMonth(month),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => onShift(1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'الشهر التالي',
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.month, required this.marks, required this.onTap});

  final DateTime month;
  final List<DayMark> marks;
  final void Function(DateTime day, DayMark? mark) onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    // الأسبوع يبدأ بالسبت في اليمن، و`weekday` يجعل الاثنين ١ والأحد ٧.
    final lead = first.weekday % 7 + 1 == 8 ? 0 : (first.weekday + 1) % 7;
    final today = DateTime.now();
    final cells = <Widget>[];

    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= days; d++) {
      final day = DateTime(month.year, month.month, d);
      final mark = marks
          .where((m) =>
              m.day.year == day.year && m.day.month == day.month && m.day.day == day.day)
          .firstOrNull;
      final past = day.isBefore(DateTime(today.year, today.month, today.day));
      cells.add(_Cell(
        day: day,
        mark: mark,
        past: past,
        onTap: past ? null : () => onTap(day, mark),
      ));
    }

    return AppCard(
      children: [
        Row(
          children: const [
            _Head('سبت'), _Head('أحد'), _Head('اثنين'), _Head('ثلاثاء'),
            _Head('أربعاء'), _Head('خميس'), _Head('جمعة'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.mark, required this.past, this.onTap});

  final DateTime day;
  final DayMark? mark;
  final bool past;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booked = mark?.byBooking ?? false;
    final closed = mark != null && !booked;
    final background = booked
        ? AppColors.accent.withValues(alpha: Tint.disc)
        : closed
            ? AppColors.critical.withValues(alpha: Tint.chip)
            : Colors.transparent;
    final ink = past
        ? AppColors.muted
        : booked
            ? AppColors.accent
            : closed
                ? AppColors.critical
                : AppColors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: mark == null ? AppColors.hairline : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 13,
            color: ink,
            fontWeight: mark == null ? FontWeight.w400 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: AppColors.accent, label: 'محجوز'),
        const SizedBox(width: 16),
        _Dot(color: AppColors.critical, label: 'أغلقتَه'),
        const SizedBox(width: 16),
        _Dot(color: AppColors.hairline, label: 'متاح'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
        ],
      );
}

/// الأيام المغلقة مكتوبةً — الشبكة تُري الشكل، وهذه تقول السبب.
class _Closed extends StatelessWidget {
  const _Closed({required this.marks, required this.onTap});

  final List<DayMark> marks;
  final void Function(DateTime day, DayMark? mark) onTap;

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) {
      return const EmptyBlock(
        title: 'شهرٌ مفتوحٌ كلُّه',
        description: 'اضغط أيَّ يومٍ لتغلقه إن كان عندك ارتباط.',
      );
    }
    return AppCard(
      children: [
        const SectionTitle('الأيام المغلقة'),
        const SizedBox(height: 8),
        for (final mark in marks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              mark.byBooking ? Icons.event_available_rounded : Icons.event_busy_rounded,
              color: mark.byBooking ? AppColors.accent : AppColors.critical,
            ),
            title: Text(formatDay(mark.day), style: const TextStyle(fontSize: 13)),
            subtitle: Text(mark.note, style: const TextStyle(fontSize: 12)),
            trailing: mark.byBooking
                ? const Text('حجز', style: TextStyle(fontSize: 11, color: AppColors.muted))
                : TextButton(
                    onPressed: () => onTap(mark.day, mark),
                    child: const Text('افتحه'),
                  ),
          ),
      ],
    );
  }
}
