import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

/// تعديل بياناتي.
///
/// **والبريد يُعرض ولا يُعدَّل، وهذا مقصود.** هو في `app_users` نسخةٌ للعرض،
/// وأصلُه في `auth.users` — به يدخل المستخدم. فحقلٌ يغيّره هنا وحده يُنتج
/// حساباً يُعرض ببريدٍ ويدخل بآخر، والمستخدم لا يفهم لماذا لا تعمل كلمته.
/// وتغييرُه الصحيح يمرّ برسالة تأكيدٍ إلى العنوان الجديد — تدفّقٌ مستقلّ.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final Session session;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  MyProfile? _profile;
  List<Governorate> _governorates = const [];
  String? _governorateId;

  /// الصورة المختارة قبل الحفظ — تُعرض فوراً ولا تُرفع إلا مع «حفظ».
  ///
  /// فمن اختار صورةً ثم عدل عن الحفظ لا يترك أثراً في السلّة.
  ({String name, Uint8List bytes})? _picked;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.myProfile(), Api.governorates()]);
      final profile = results[0] as MyProfile?;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _governorates = results[1] as List<Governorate>;
        _governorateId = profile?.governorateId;
        _name.text = profile?.fullName ?? '';
        _phone.text = profile?.phone ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // يُقاس ويُضغط عند الالتقاط لا بعده: صورةُ كاميرا الجوال تتجاوز خمسة
      // ميجابايت، وحدُّ السلّة اثنان — ورفعُها على شبكةٍ يمنية عذاب.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return; // إلغاءٌ لا خطأ
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picked = (name: file.name, bytes: bytes);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = messageOf(e));
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'اكتب اسمك كاملاً.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // الصورة تُرفع أوّلاً ثم يُحفظ مسارها: لو حُفظ المسار قبل الرفع ونجح
      // الأوّل وفشل الثاني لأشار الملفُّ إلى صورةٍ لا وجود لها.
      String? avatarPath;
      final picked = _picked;
      if (picked != null && widget.session.userId != null) {
        avatarPath = await Api.uploadAvatar(
          authUserId: widget.session.userId!,
          fileName: picked.name,
          bytes: picked.bytes,
        );
      }
      await Api.updateProfile(
        fullName: name,
        phone: _phone.text.trim(),
        governorateId: _governorateId,
        avatarPath: avatarPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بياناتي')),
      body: _loading
          ? const LoadingBlock()
          : _profile == null
          ? ErrorBlock(message: _error ?? 'لا ملفَّ لحسابك بعد.', onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                Center(child: _Avatar(profile: _profile!, picked: _picked, onTap: _choosePhoto)),
                const SizedBox(height: Space.xl),
                AppCard(
                  children: [
                    const SectionTitle('بياناتي'),
                    const SizedBox(height: Space.lg),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      // الأرقام لاتينية والسياق عربيّ: بلا اتجاهٍ صريح يتقدّم
                      // رمز الدولة إلى آخر الرقم.
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجوال',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    DropdownButtonFormField<String>(
                      initialValue: _governorateId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      items: [
                        for (final g in _governorates)
                          DropdownMenuItem(value: g.id, child: Text(g.name)),
                      ],
                      onChanged: (v) => setState(() => _governorateId = v),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AppCard(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SectionTitle('البريد الإلكتروني')),
                        const StatusBadge('لا يُعدَّل هنا'),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      _profile!.email,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    const Text(
                      'به تدخل إلى حسابك، وتغييره يحتاج رسالة تأكيدٍ إلى العنوان الجديد. '
                      'راسل الدعم لتغييره.',
                      style: TextStyle(fontSize: 12, height: 1.7, color: AppColors.muted),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.critical, height: 1.7, fontSize: 13),
                  ),
                ],
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات'),
                ),
                const SizedBox(height: Space.xl),
              ],
            ),
    );
  }
}

/// دائرة الصورة وزرُّ الكاميرا.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.picked, required this.onTap});
  final MyProfile profile;
  final ({String name, Uint8List bytes})? picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = Api.avatarUrl(profile.avatarPath);
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _content(url),
          ),
          // زرّ الكاميرا في الأسفل يساراً — لا يغطّي الوجه في الصورة.
          PositionedDirectional(
            bottom: 0,
            start: 0,
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(String? url) {
    final p = picked;
    if (p != null) {
      // المختارة تُعرض من الذاكرة فوراً — قبل أن تُرفع، فيرى النتيجة قبل الحفظ.
      return Image.memory(p.bytes, fit: BoxFit.cover, width: 108, height: 108);
    }
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 108,
        height: 108,
        // شبكةٌ تسقط لا تُخرج مربّعاً مكسوراً: يُعاد الحرف.
        errorBuilder: (_, _, _) => _initial(),
      );
    }
    return _initial();
  }

  Widget _initial() {
    final clean = profile.fullName.trim();
    return Text(
      clean.isEmpty ? '؟' : clean.characters.first,
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: AppColors.accentInk,
        fontFamilyFallback: arabicFallback,
      ),
    );
  }
}
