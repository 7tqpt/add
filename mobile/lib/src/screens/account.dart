import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/app_version.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import '../ui/photo_view.dart';
import '../ui/pick_image.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart' show messageOf;
import 'account_extras.dart';
import 'become_provider.dart';
import 'disputes.dart';
import 'favourites.dart';
import 'edit_profile.dart';
import 'money.dart';
import 'support.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.session});
  final Session session;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  /// الملفُّ من القاعدة لا من الجلسة.
  ///
  /// كانت البطاقة تقرأ `session.email` وحده — وهو كلُّ ما تحمله الجلسة. فكان
  /// المستخدم يحفظ اسمه وجواله وصورته في «تعديل بياناتي» ثم يعود فلا يجد
  /// لها أثراً حيث ينظر، ويظنّ أن الحفظ لم يقع.
  MyProfile? _profile;

  /// ختمٌ زمنيّ يُلحق برابط الصورة.
  ///
  /// السلّة عامّة والاسم ثابت (`<uid>/avatar.jpg`)، فبعد استبدال الصورة يعرض
  /// التطبيق القديمةَ من ذاكرته. والختم يغيّر العنوان فيُجبره على الجلب.
  int _avatarVersion = 0;

  /// الغلافُ يُرفع الآن — يُعطَّل الزرّ وتدور دوّارةٌ مكان الرمز.
  bool _coverBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await Api.myProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // الملفُّ زينةٌ في هذه الشاشة لا شرط: بقيّةُ البطاقات تعمل بدونه،
      // فيبقى البريد من الجلسة ويُعرض الحرفُ الأوّل.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final provider = session.hasProviderProfile;
    final profile = _profile;

    return ListView(
      padding: EdgeInsets.only(bottom: glassNavSpace),
      children: [
        // ── الرأسُ النبيذيّ ────────────────────────────────────────────────
        // من رسمك: صورةٌ بطوقٍ ذهبيّ، والاسمُ والجوال، وشارةُ الدور ذهبيّة.
        //
        // ويمتدّ إلى حافّتَي الشاشة ويبدأ من أعلاها — فيمرّ تحت الشريط
        // الزجاجي بدل أن يقف تحته بحاشيةٍ بيضاء تقطع النبيذيّ نصفين.
        ProfileHeader(
          // **والغلافُ لمن له ملفٌّ وحده.** قبل وصوله لا يُعرف اسمُه،
          // و`api_update_profile` تشترط اسماً — فزرٌّ يُضغط فيردّ «الاسم قصير
          // جداً» على من لم يكتب شيئاً أسوأُ من زرٍّ يتأخّر لحظة.
          coverUrl: profile == null
              ? null
              : Api.avatarUrl(profile.coverPath, version: _avatarVersion),
          onEditCover: profile == null ? null : () => _changeCover(profile),
          coverBusy: _coverBusy,
          // **والقرصُ يُضغط كالغلاف.** كان وحدَه المتحجّرَ في التطبيق:
          // قرصُ المزوّد يُضغط، وقرصُ «تعديل بياناتي» يُضغط، وهذا لا.
          avatar: GestureDetector(
            key: const ValueKey('account-avatar-tap'),
            onTap: profile == null
                ? null
                : () => openPhoto(
                      context,
                      url: Api.avatarUrl(profile.avatarPath,
                          version: _avatarVersion),
                      onEdit: () => _changeAvatar(profile),
                    ),
            child: _AccountAvatar(
              profile: profile,
              fallbackEmail: session.email,
              version: _avatarVersion,
              size: profileAvatarSize,
            ),
          ),
          title: (profile?.fullName.trim().isNotEmpty ?? false)
              ? profile!.fullName.trim()
              : session.email,
          subtitle: (profile?.phone.trim().isNotEmpty ?? false)
              ? profile!.phone.trim()
              : ((profile?.fullName.trim().isNotEmpty ?? false) ? session.email : ''),
          // **والاتجاهُ يتبع ما يُعرض لا الصفحة.** قبل وصول الملفّ يقع البريدُ
          // في مكان الاسم، وهو لاتينيٌّ دائماً — وبلا `ltr` تتقدّم نقطتُه
          // وامتدادُه إلى غير موضعهما فيُقرأ مقلوباً. كشفه اختبارٌ سقط حين
          // أُخرج الرأسُ إلى الكِت وأُسقط عنه الاتجاه.
          titleLtr: !(profile?.fullName.trim().isNotEmpty ?? false),
          subtitleLtr: true,
          badge: weddingRoleLabel(profile?.weddingRole ?? '', provider: provider),
        ),

        // ── الأبواب ────────────────────────────────────────────────────────
        MenuSheet(
          children: [
            MenuRow(
              icon: Icons.person_outline_rounded,
              label: tr('الملف الشخصي'),
              onTap: () => _openProfile(context),
            ),
            MenuRow(
              icon: Icons.receipt_long_outlined,
              label: tr('فواتيري'),
              onTap: () =>
                  _push(context, tr('فواتيري'), InvoicesScreen(session: session)),
            ),
            MenuRow(
              icon: Icons.favorite_border_rounded,
              label: tr('المفضّلة'),
              onTap: () => _push(context, tr('المفضّلة'), const FavouritesScreen()),
            ),
            // **صارت أبواباً تفتح، لا صفوفاً في لوحةِ تصميم.**
            MenuRow(
              icon: Icons.location_on_outlined,
              label: tr('العناوين'),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AddressesScreen())),
            ),
            MenuRow(
              icon: Icons.credit_card_outlined,
              label: tr('طرق الدفع'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            ),
            // مقدّمُ الخدمة: بابٌ واحدٌ بوجهين — من له ملفٌّ يبدّل الوضع، ومن
            // لا ملفَّ له يطلبه. ولا يُعرض البابان معاً فيحتار أيَّهما له.
            MenuRow(
              icon: provider ? Icons.storefront_outlined : Icons.add_business_outlined,
              label: provider
                  ? tr('التبديل إلى وضع مقدّم الخدمة')
                  : tr('أريد تقديم خدمة'),
              onTap: provider
                  ? () => session.switchTo(provider: true)
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BecomeProviderScreen(session: session),
                      ),
                    ),
              last: true,
            ),

            const MenuGap(),

            MenuRow(
              icon: Icons.settings_outlined,
              label: tr('الإعدادات'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => SettingsScreen(session: session))),
            ),
            MenuRow(
              icon: Icons.support_agent_outlined,
              label: tr('الدعم'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => SupportScreen(session: session))),
            ),
            MenuRow(
              icon: Icons.gavel_rounded,
              label: tr('النزاعات'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => DisputesScreen(session: session))),
            ),
            // الخروجُ بصبغة التحذير وآخرَ القائمة: هو الإجراء الوحيد هنا
            // الذي يُخرجك، فيُعرَف قبل أن يُضغط. ويُسأل عنه لأن ضغطةً بالخطأ
            // تُخرج المستخدم ثم تطلب منه بريده وكلمته.
            MenuRow(
              icon: Icons.logout_rounded,
              label: tr('تسجيل الخروج'),
              tone: AppColors.critical,
              onTap: () => _confirmSignOut(context),
              last: true,
            ),
          ],
        ),

        const SizedBox(height: Space.lg),
        Center(child: Muted(appVersionLabel, size: 11)),
        const SizedBox(height: Space.lg),
      ],
    );
  }

  /// يبدّل غلافَ الملفّ — يُختار ويُرفع ويُحفظ في نداءٍ واحدٍ بلا شاشة.
  ///
  /// **ومكانُ تغيير الصورة هو الصورةُ نفسها** — كما في شعار المزوّد، لا حقلٌ
  /// في شاشةِ تعديلٍ يُبحث عنه.
  ///
  /// **والرفعُ قبل الحفظ:** لو حُفظ المسارُ أوّلاً ونجح ثمّ سقط الرفعُ لأشار
  /// الملفُّ إلى صورةٍ لا وجود لها — فيرى صاحبُه غلافاً مكسوراً كلَّ مرّة.
  Future<void> _changeCover(MyProfile profile) async {
    final userId = widget.session.userId;
    // **ولا بابٌ صامت.** كان `return` وحدَه: يُضغط الزرُّ فلا يقع شيءٌ ولا
    // يُقال شيء، وصاحبُه يظنّ التطبيقَ معطوباً — وهو أسوأُ من رسالةِ خطأ.
    // وكلُّ طريقٍ في هذه الدالّة يجب أن ينتهي إمّا بصورةٍ أو بكلمة.
    if (userId == null) {
      showMessage(context, tr('سجّل الدخول أولاً.'));
      return;
    }
    try {
      final picked = await pickImage(
        context,
        maxWidth: coverMaxWidth,
        maxHeight: coverMaxHeight,
      );
      if (picked == null) return; // إلغاءٌ لا خطأ
      if (!mounted) return;
      setState(() => _coverBusy = true);

      final path = await Api.uploadCover(
        authUserId: userId,
        fileName: picked.name,
        bytes: picked.bytes,
      );
      await Api.updateProfile(fullName: profile.fullName, coverPath: path);
      if (!mounted) return;
      // الختمُ يتغيّر فيُجبر التطبيقَ على جلب الجديدة: السلّةُ عامّةٌ
      // والاسمُ ثابت، فبلا فرقٍ في العنوان يعرض القديمةَ من ذاكرته.
      setState(() => _avatarVersion++);
      await _load();
      if (mounted) showMessage(context, tr('حُفظ الغلاف'));
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  /// يبدّل صورةَ الملفّ — كما يُبدَّل الغلاف، من موضعها لا من شاشةٍ أخرى.
  ///
  /// **ومقاسُها ‎٨٠٠×٨٠٠‎ لا مقاسُ الغلاف:** قرصٌ قطرُه تسعون بكسلاً لا
  /// يحتاج أكثر، ورفعُ ‎١٦٠٠×٩٠٠‎ على شبكةٍ يمنيّةٍ لأجله عذابٌ بلا مقابل.
  Future<void> _changeAvatar(MyProfile profile) async {
    final userId = widget.session.userId;
    if (userId == null) {
      showMessage(context, tr('سجّل الدخول أولاً.'));
      return;
    }
    try {
      final picked = await pickImage(context, maxWidth: 800, maxHeight: 800);
      if (picked == null) return; // إلغاءٌ لا خطأ
      if (!mounted) return;

      // **والرفعُ قبل الحفظ:** لو حُفظ المسارُ ونجح ثمّ سقط الرفعُ لأشار
      // الملفُّ إلى صورةٍ لا وجود لها.
      final path = await Api.uploadAvatar(
        authUserId: userId,
        fileName: picked.name,
        bytes: picked.bytes,
      );
      await Api.updateProfile(fullName: profile.fullName, avatarPath: path);
      if (!mounted) return;
      setState(() => _avatarVersion++);
      await _load();
      if (mounted) showMessage(context, tr('حُفظت صورتك.'));
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
  }

  /// يفتح شاشةً لها شريطُ عنوانٍ خاصّ بها.
  void _push(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        ),
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(session: widget.session)),
    );
    if (saved == true) {
      // الختم يتغيّر فيُجبر التطبيق على جلب الصورة الجديدة بدل القديمة التي
      // في ذاكرته.
      if (mounted) setState(() => _avatarVersion++);
      await _load();
      if (context.mounted) showMessage(context, tr('حُفظت بياناتك.'));
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('تسجيل الخروج؟')),
        content: Text(
          tr('ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.'),
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            child: Text(tr('خروج')),
          ),
        ],
      ),
    );
    if (yes == true) widget.session.signOut();
  }
}

/// قرص الصورة في بطاقة الهويّة.
///
/// الصورة إن وُجدت، وإلا فالحرف الأوّل. ولا مربّعَ مكسور إن سقطت الشبكة:
/// `errorBuilder` يعيد الحرف — فالشاشة تبقى سليمة على وصلةٍ رديئة.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.profile,
    required this.fallbackEmail,
    required this.version,
    this.size = 56,
  });

  final MyProfile? profile;
  final String fallbackEmail;
  final int version;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = profile?.avatarPath ?? '';
    final url = path.isEmpty ? null : Api.avatarUrl(path, version: version);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      // **قرصٌ أعمقُ من النبيذيّ داخل الرأس النبيذيّ.** لولا ذلك لَذاب حرفُ
      // من لا صورةَ له في أرضيّته فلم يُرَ منه شيء.
      decoration: const BoxDecoration(
        color: AppColors.accentDeep,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? _letter()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _letter(),
            ),
    );
  }

  Widget _letter() {
    // الاسم أولى من البريد: «أ» من «أيمن» تعني صاحبها، و«a» من عنوانٍ لا.
    final name = profile?.fullName.trim() ?? '';
    final source = name.isNotEmpty ? name : fallbackEmail.trim();
    return Text(
      source.isEmpty ? tr('؟') : source.characters.first.toUpperCase(),
      // النمط كاملٌ مكتوبٌ باليد، فيُذكر الخطّ صراحةً: النمط الكامل يحلّ محلّ
      // الموروث ولا يرث احتياط الثيمة.
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w600,
        color: AppColors.accentInk,
        fontFamilyFallback: arabicFallback,
      ),
    );
  }
}
