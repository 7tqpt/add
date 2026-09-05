import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/app_version.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import '../data/api.dart';
import '../data/models.dart';
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
          avatar: _AccountAvatar(
            profile: profile,
            fallbackEmail: session.email,
            version: _avatarVersion,
            size: 64,
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
              label: 'الملف الشخصي',
              onTap: () => _openProfile(context),
            ),
            MenuRow(
              icon: Icons.receipt_long_outlined,
              label: 'فواتيري',
              onTap: () => _push(
                context,
                'فواتيري',
                InvoicesScreen(session: session),
              ),
            ),
            MenuRow(
              icon: Icons.favorite_border_rounded,
              label: 'المفضّلة',
              onTap: () => _push(context, 'المفضّلة', const FavouritesScreen()),
            ),
            // **صارت أبواباً تفتح، لا صفوفاً في لوحةِ تصميم.**
            MenuRow(
              icon: Icons.location_on_outlined,
              label: 'العناوين',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              ),
            ),
            MenuRow(
              icon: Icons.credit_card_outlined,
              label: 'طرق الدفع',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
              ),
            ),
            // مقدّمُ الخدمة: بابٌ واحدٌ بوجهين — من له ملفٌّ يبدّل الوضع، ومن
            // لا ملفَّ له يطلبه. ولا يُعرض البابان معاً فيحتار أيَّهما له.
            MenuRow(
              icon: provider
                  ? Icons.storefront_outlined
                  : Icons.add_business_outlined,
              label: provider ? 'التبديل إلى وضع مقدّم الخدمة' : 'أريد تقديم خدمة',
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
              label: 'الإعدادات',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(session: session)),
              ),
            ),
            MenuRow(
              icon: Icons.support_agent_outlined,
              label: 'الدعم',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SupportScreen(session: session)),
              ),
            ),
            MenuRow(
              icon: Icons.gavel_rounded,
              label: 'النزاعات',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DisputesScreen(session: session)),
              ),
            ),
            // الخروجُ بصبغة التحذير وآخرَ القائمة: هو الإجراء الوحيد هنا
            // الذي يُخرجك، فيُعرَف قبل أن يُضغط. ويُسأل عنه لأن ضغطةً بالخطأ
            // تُخرج المستخدم ثم تطلب منه بريده وكلمته.
            MenuRow(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
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

  /// يفتح شاشةً لها شريطُ عنوانٍ خاصّ بها.
  void _push(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
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
      if (context.mounted) showMessage(context, 'حُفظت بياناتك.');
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
          'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            child: const Text('خروج'),
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
      source.isEmpty ? '؟' : source.characters.first.toUpperCase(),
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
