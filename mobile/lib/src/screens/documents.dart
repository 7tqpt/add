import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _upload(String type, ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      // ضغطٌ عند الالتقاط: صورة هوية بدقّة الكاميرا كاملةً تتجاوز حدّ الحاوية
      // على كثيرٍ من الأجهزة، وهي تُقرأ بلا تلك الدقّة.
      maxWidth: 2200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();

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

  /// النوع أوّلاً ثم المصدر: الكاميرا أو المعرض.
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
    if (type == null || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(Space.lg), child: SectionTitle('من أين؟')),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: const Text('التقط صورة'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('من المعرض'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: Space.md),
          ],
        ),
      ),
    );
    if (source != null) await _upload(type, source);
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
                    'صوّر هويتك الشخصية، والسجل التجاري إن وُجد. الصور خاصّة '
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
                    description: 'صوّر هويتك ليبدأ فريق التوثيق مراجعة ملفك.',
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
