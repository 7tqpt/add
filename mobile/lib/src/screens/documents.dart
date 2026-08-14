import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'labels.dart';

/// مستندات التوثيق.
///
/// شاشة الملف تقول «لن تستقبل حجوزات حتى تُقبل مستنداتك» ولم يكن هناك طريقٌ
/// لرفعها — فكان الوعد بابًا مغلقاً. الحاوية `provider-docs` خاصّة، والمسؤول
/// وحده يوقّع رابطاً مؤقّتاً لرؤيتها من اللوحة.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.session});
  final Session session;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<ProviderDocument>> _future;
  bool _busy = false;

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

  Future<void> _upload(String type) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      // الحاوية تقبل هذه الامتدادات وحدها؛ تقييد المنتقي يمنع اختياراً سيُرفض
      // بعد انتظار الرفع.
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    // حدّ الحاوية عشرة ميغابايت، ورفضُها يصل رسالةً غامضة بعد رفعٍ طويل على
    // شبكةٍ بطيئة. الفحص هنا يوفّر ذلك كلّه.
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      if (mounted) showMessage(context, 'الملف أكبر من 10 ميغابايت — اختر نسخةً أصغر.');
      return;
    }

    setState(() => _busy = true);
    try {
      await Api.uploadDocument(
        providerId: widget.session.providerId ?? '',
        type: type,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      showMessage(context, 'رُفع المستند — تراجعه الإدارة.');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(Space.lg), child: SectionTitle('نوع المستند')),
            for (final entry in documentTypes)
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppColors.accent),
                title: Text(entry.label),
                onTap: () => Navigator.of(context).pop(entry.value),
              ),
            const SizedBox(height: Space.md),
          ],
        ),
      ),
    );
    if (type != null) await _upload(type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مستندات التوثيق')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _pickType,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file),
        label: Text(_busy ? 'جارٍ الرفع…' : 'رفع مستند'),
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
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 96),
            children: [
              const AppCard(
                children: [
                  SectionTitle('ما المطلوب'),
                  SizedBox(height: Space.sm),
                  Text(
                    'صورة الهوية الشخصية، والسجل التجاري إن وُجد. الملفات خاصّة '
                    'لا يراها إلا فريق التوثيق، ولا تظهر للعملاء إطلاقاً.',
                    style: TextStyle(height: 1.7),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Space.xl),
                  child: EmptyBlock(
                    title: 'لم ترفع شيئاً بعد',
                    description: 'ارفع هويتك ليبدأ فريق التوثيق مراجعة ملفك.',
                  ),
                )
              else
                for (final doc in rows) ...[
                  AppCard(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SectionTitle(documentTypeLabel(doc.type))),
                          const SizedBox(width: Space.sm),
                          StatusBadge(
                            documentStatusLabel(doc.status),
                            color: documentStatusColor(doc.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Muted(doc.fileName),
                      const SizedBox(height: Space.xs),
                      Muted(formatRelative(doc.uploadedAt), size: 11),
                      if (doc.note.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        Text(
                          doc.note,
                          style: const TextStyle(
                            color: AppColors.critical,
                            fontSize: 13,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.md),
                ],
            ],
          );
        },
      ),
    );
  }
}
