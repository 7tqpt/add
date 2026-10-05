import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_lock.dart';
import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/auth_frame.dart' show authPaper;
import '../ui/kit.dart';
import 'labels.dart';

/// مستندات التوثيق.
///
/// شاشة الملف تقول «لن تستقبل حجوزات حتى تُقبل مستنداتك» ولم يكن هناك طريقٌ
/// لرفعها — فكان الوعد بابًا مغلقاً. الحاوية `provider-docs` خاصّة، والمسؤول
/// وحده يوقّع رابطاً مؤقّتاً لرؤيتها من اللوحة.
///
/// الرفع صورةٌ لا ملفاً: `image_picker` من فريق Flutter نفسه، بعد أن تبيّن أن
/// `file_picker` — وهي التي تفتح ملفات PDF أيضاً — لا تُبنى مع AGP 9 لأنها
/// تثبّت Kotlin 1.8 في بنائها. وصاحب القاعة يصوّر هويته بجواله على كل حال،
/// والحاوية تقبل الصور. أمّا PDF فتبقى مقبولةً في الحاوية لمن يرفع من اللوحة.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.session});
  final Session session;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

/// خانةٌ في الشاشة — نوعُ المستند كما تقيّده القاعدة، وما يُكتب فوقه.
typedef _Slot = ({String type, String title, String hint, String icon});

/// صورةٌ اختيرت ولم تُرفع بعد.
typedef _Picked = ({String name, Uint8List bytes});

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<ProviderDocument>> _future;
  bool _busy = false;

  /// **ما اختير ولم يُرفع** — لكلّ خانةٍ صورُها. والرفعُ كلُّه بزرٍّ واحدٍ
  /// في الأسفل، كما في صورة صاحب المنصّة: «رفع المستندات».
  final Map<String, List<_Picked>> _picked = {};

  /// **ثلاثُ خاناتٍ من صورته**، كلٌّ بنوعٍ تقبله القاعدة
  /// (`provider_documents.type`). والثالثةُ «صورة خاصة بالقسم المطلوب» —
  /// ترخيصُ القسم أو شهادتُه — فهي `certificate`.
  ///
  /// **ودالّةٌ لا ثابت**: النصوصُ تمرّ بـ`tr`، فتُبنى عند كلّ رسم.
  List<_Slot> get _slots => [
    (type: 'id_card', title: tr('البطاقة الشخصية'), hint: tr('صورة واضحة للوجهين'), icon: 'doc_idcard'),
    (type: 'commercial_register', title: tr('السجل التجاري'), hint: tr('إن وجد'), icon: 'doc_doc'),
    (type: 'certificate', title: tr('صورة خاصة بالقسم المطلوب'), hint: tr('لا تظهر للعملاء'), icon: 'doc_image'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProviderDocument>> _load() {
    final id = widget.session.providerId;
    return id == null ? Future.value(const []) : Api.myDocuments(id);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// يختار صورةً لخانةٍ — من الكاميرا أو المعرض — **ولا يرفعها**.
  Future<void> _add(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(Space.lg), child: SectionTitle(tr('من أين؟'))),
            ListTile(
              key: const ValueKey('doc-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: Text(tr('التقط صورة')),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('doc-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: Text(tr('من المعرض')),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: Space.md),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    // **ورحلةٌ لا غياب** — انظر `awayFromApp`.
    final file = await awayFromApp(
      () => (documentPickerOverride ?? _systemPicker)(source),
    );
    if (file == null) return;

    // حدّ الحاوية عشرة ميغابايت، ورفضُها يصل رسالةً غامضة بعد رفعٍ طويل على
    // شبكةٍ بطيئة. الفحص هنا يوفّر ذلك كلّه.
    if (file.bytes.lengthInBytes > 10 * 1024 * 1024) {
      if (mounted) showMessage(context, tr('الملف أكبر من 10 ميغابايت — اختر نسخةً أصغر.'));
      return;
    }
    if (!mounted) return;
    setState(() => (_picked[type] ??= []).add(file));
  }

  static Future<_Picked?> _systemPicker(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      // ضغطٌ عند الالتقاط: صورة هوية بدقّة الكاميرا كاملةً تتجاوز حدّ الحاوية
      // على كثيرٍ من الأجهزة، وهي تُقرأ بلا تلك الدقّة.
      maxWidth: 2200,
      imageQuality: 85,
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }

  /// يرفع كلَّ ما اختير — خانةً خانة، وصورةً صورة.
  ///
  /// **وما رُفع يُرفع من القائمة فورَ رفعه**، لا في الآخر: عطبٌ في الثالثة
  /// يُبقي الثالثةَ وما بعدها، ولا يُعيد رفعَ الأوليين إن أعاد المحاولة.
  Future<void> _uploadAll() async {
    if (_picked.values.every((l) => l.isEmpty)) {
      showMessage(context, tr('أضف صورةً واحدةً على الأقلّ.'));
      return;
    }
    setState(() => _busy = true);
    try {
      for (final slot in _slots) {
        final list = _picked[slot.type] ?? [];
        while (list.isNotEmpty) {
          final file = list.first;
          await Api.uploadDocument(
            providerId: widget.session.providerId ?? '',
            type: slot.type,
            fileName: file.name,
            bytes: file.bytes,
          );
          if (!mounted) return;
          setState(() => list.removeAt(0));
        }
      }
      if (!mounted) return;
      showMessage(context, tr('رُفعت المستندات — تراجعها الإدارة.'));
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── على صورة صاحب المنصّة ──────────────────────────────────────────────────
  //
  // «غير لي» — بصورة: بطاقةُ «ما المطلوب؟» بدرعٍ ذهبيّ، ثمّ ثلاثُ خاناتٍ لكلٍّ
  // صندوقٌ متقطّعٌ «إضافة صورة»، ثمّ سطرُ «للإدارة فقط» وزرُّ «رفع المستندات».
  //
  // **وما لم يكن في الصورة وأُبقي:** ما رُفع من قبلُ يُعرض في خانته بحاله
  // («قيد المراجعة» أو «مقبول» أو «مرفوض» وسببِه) — وإلّا لم يعرف المرفوضُ
  // لماذا رُفض. وكانت «تأمين» و«نماذج أعمال» نوعين في القائمة القديمة،
  // فسقطا من الشاشة وبقيا في القاعدة واللوحة.

  static const _edge = Color(0xFFEBDACD);
  static const _gold = Color(0xFFB08A5E);
  static const _disc = Color(0xFFF6ECE2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authPaper,
      appBar: AppBar(
        backgroundColor: authPaper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.accent,
        title: Text(
          tr('مستندات التوثيق'),
          style: const TextStyle(color: AppColors.ink, fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<ProviderDocument>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
          }
          final rows = snap.data ?? const <ProviderDocument>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              _Info(edge: _edge, gold: _gold, disc: _disc),
              const SizedBox(height: 12),
              for (final slot in _slots) ...[
                _SlotCard(
                  slot: slot,
                  uploaded: [for (final d in rows) if (d.type == slot.type) d],
                  picked: _picked[slot.type] ?? const [],
                  busy: _busy,
                  onAdd: () => _add(slot.type),
                  onRemove: (i) => setState(() => _picked[slot.type]!.removeAt(i)),
                  edge: _edge,
                  gold: _gold,
                  disc: _disc,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Mark('doc_shield_small', color: _gold, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      tr('تُظهر هذه الصور للإدارة فقط'),
                      key: const ValueKey('docs-admin-only'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const ValueKey('docs-upload'),
                onPressed: _busy ? null : _uploadAll,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _busy ? tr('جارٍ الرفع…') : tr('رفع المستندات'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    if (_busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const _Mark('doc_upload', color: Colors.white, size: 26, key: ValueKey('docs-upload-mark')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// أيقونةٌ من صورة صاحب المنصّة — **مقصوصةٌ منها قناعَ ألفا أبيض** وتُلوَّن
/// هنا (`assets/brand/doc_*.png`). أيقوناتُ المكتبة رُسمت مصمتةً ثقيلة،
/// وأيقوناتُه خطوطٌ رفيعة.
class _Mark extends StatelessWidget {
  const _Mark(this.name, {super.key, required this.color, required this.size});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/brand/$name.png',
      key: ValueKey('mark-$name'),
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) => SizedBox(height: size, width: size),
    ),
  );
}

/// قرصٌ كريميٌّ فيه أيقونةٌ ذهبيّة — رأسُ كلّ بطاقة.
class _Disc extends StatelessWidget {
  const _Disc({required this.child, required this.size, required this.color});
  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: child,
  );
}

BoxDecoration _cardBox(Color edge) => BoxDecoration(
  color: const Color(0xFFFDF9F6),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: edge),
);

/// «ما المطلوب؟» — بدرعٍ ذهبيٍّ في قرص.
class _Info extends StatelessWidget {
  const _Info({required this.edge, required this.gold, required this.disc});
  final Color edge;
  final Color gold;
  final Color disc;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('docs-info'),
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
    decoration: _cardBox(edge),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Disc(size: 62, color: disc, child: _Mark('doc_shield', color: gold, size: 42)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('ما المطلوب؟'),
                style: const TextStyle(color: AppColors.accent, fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                tr('صورة هويتك الشخصية، والسجل التجاري إن وجد. الصور خاصة بالإدارة لغرض التوثيق، ولا تظهر للعملاء إطلاقاً.'),
                style: const TextStyle(color: AppColors.ink2, fontSize: 14.5, height: 1.75),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// خانةُ نوعٍ: رأسُها، وما رُفع فيها بحاله، وما اختير ولم يُرفع، وصندوقُ الإضافة.
class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.uploaded,
    required this.picked,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    required this.edge,
    required this.gold,
    required this.disc,
  });

  final _Slot slot;
  final List<ProviderDocument> uploaded;
  final List<_Picked> picked;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final Color edge;
  final Color gold;
  final Color disc;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('doc-slot-${slot.type}'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: _cardBox(edge),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Disc(size: 52, color: disc, child: _Mark(slot.icon, color: gold, size: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.title,
                    style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(slot.hint, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        // ما رُفع من قبلُ — بحاله، وسببِ الرفض إن رُفض.
        for (final doc in uploaded) ...[
          const SizedBox(height: 10),
          Row(
            key: ValueKey('doc-uploaded-${doc.id}'),
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Muted(doc.fileName, maxLines: 1)),
              const SizedBox(width: 8),
              StatusBadge(documentStatusLabel(doc.status), color: documentStatusColor(doc.status)),
            ],
          ),
          if (doc.note.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 24, top: 4),
              child: Text(doc.note, style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.6)),
            ),
        ],
        const SizedBox(height: 12),
        // ما اختير ولم يُرفع — مصغّراتٌ بزرّ إزالة.
        if (picked.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < picked.length; i++)
                Stack(
                  key: ValueKey('doc-picked-${slot.type}-$i'),
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: disc,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: edge),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        picked[i].bytes,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: disc,
                          child: Icon(Icons.image_outlined, color: gold),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: -6,
                      end: -6,
                      child: GestureDetector(
                        onTap: busy ? null : () => onRemove(i),
                        child: Container(
                          key: ValueKey('doc-remove-${slot.type}-$i'),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _AddBox(key: ValueKey('doc-add-${slot.type}'), onTap: busy ? null : onAdd),
      ],
    ),
  );
}

/// صندوقٌ متقطّعُ الحافّة: ورقةٌ بزائدٍ و«إضافة صورة».
class _AddBox extends StatelessWidget {
  const _AddBox({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: const _DashedBox(color: Color(0xFFE2CDB8), radius: 16),
        // **أدنى ارتفاعٍ لا ارتفاعٌ ثابت:** بخطّ الجهاز الكبير يطول السطرُ،
        // وارتفاعٌ ثابتٌ يقصّه.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const _Mark('doc_fileplus', color: AppColors.accent, size: 44),
              const SizedBox(height: 6),
              Text(
                tr('إضافة صورة'),
                style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

/// حافّةٌ متقطّعةٌ حول مستطيلٍ مستدير — لا تأتي بها `BoxDecoration`.
class _DashedBox extends CustomPainter {
  const _DashedBox({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, (d + 6).clamp(0, metric.length)), pen);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color || old.radius != radius;
}

/// يختار الصورةَ بدل منتقي النظام — في الاختبارات وحدها؛ لا منتقي في `flutter test`.
Future<({String name, Uint8List bytes})?> Function(ImageSource source)? documentPickerOverride;
