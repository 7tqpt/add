import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// عناصر الواجهة المشتركة.

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.children, this.onTap});
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
  );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 12, this.maxLines});
  final String text;
  final double size;

  /// حدُّ الأسطر — يُترك فارغاً فيلتفّ النصّ كما كان.
  ///
  /// يُمرَّر حيث يكون النصّ في صفٍّ ضيّق: مبلغان بالريال اليمني جنباً إلى جنب
  /// تجاوزا عرض الجوال بستّةٍ وأربعين بكسلاً، والأرقام هنا تطول بطبعها.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(fontSize: size, color: AppColors.muted),
  );
}

/// تقييمٌ بنجمة وعدد.
///
/// النجمة أيقونة لا حرف «★»: الحرف خارج تغطية معظم خطوط الواجهة، فيظهر مربّعاً
/// فارغاً على الأجهزة التي لا تحمل خطّ الرموز. وأيقونات Material مرفقة بالحزمة
/// فترسم دائماً.
class Rating extends StatelessWidget {
  const Rating(this.value, {super.key, this.count, this.size = 12});
  final num value;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ذهبٌ لا كهرمانُ التحذير: نجمةٌ بلون «انتبه» تجعل التقييمَ العاليَ
        // يُقرأ إنذاراً. وهو `gold` المقيس (‎٤٫٦٨:١‎) لا ذهبُ الشعار الفاتح
        // الذي لا يُقرأ على أبيض.
        Icon(Icons.star_rounded, size: size + 4, color: AppColors.gold),
        const SizedBox(width: 2),
        Muted(count == null ? '$value' : '$value ($count)', size: size),
      ],
    );
  }
}

/// شارة حالة — لون وحدّ، مع نصّ يُقرأ بلا الاعتماد على اللون.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color = AppColors.muted});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(999),
    ),
    // سطرٌ واحد وقصٌّ عند الضيق: شارةٌ تلتفّ سطرين تكسر ارتفاع الصفّ الذي
    // هي فيه، وشارةٌ تفيض تُسقط التخطيط كلّه. و«بانتظار مقدّم الخدمة» أطولُ
    // نصٍّ فيها — وقد أفاض بطاقةَ الرئيسية ستّةً وأربعين بكسلاً.
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// علامةُ التوثيق — قرصٌ بلون العلامة فيه صحّ.
///
/// تقع **إلى جانب الاسم** لا في سطرٍ تحته: هي صفةٌ للاسم لا خبرٌ مستقلّ، ومن
/// رآها لصيقةً به عرف من فوره أن هذا هو المزوّد الذي وثّقته الإدارة لا اسماً
/// كتبه من شاء.
///
/// وحجمُها من حجم النصّ الذي تجاوره: علامةٌ بحجمٍ ثابت إلى جانب اسمٍ كبير
/// تبدو منسيّة، وإلى جانب اسمٍ صغير تبدو دخيلة.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 18, this.tooltip = 'مزوّد موثَّق'});
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
      // الأبيض على أزرق العلامة ‎٧٫٥٥:١‎ — مقيسٌ لا مفترَض.
      child: Icon(Icons.check_rounded, size: size * 0.68, color: AppColors.accentInk),
    ),
  );
}

/// صورةُ مقدّم الخدمة: شعارُه إن رفعه، وإلّا حرفُه في قرص.
///
/// **والحرفُ ليس عيباً يُخفى:** جدولُ المزوّدين لا يفرض شعاراً، فمن لم يرفع
/// شيئاً يُعرض بحرفه بلونٍ من لون العلامة — لا بإطارٍ رماديٍّ فارغ يقول إن
/// صورةً لم تُحمَّل، ولا بأيقونةِ صورةٍ مكسورة.
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 54,
    this.ring = 0,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// إطارٌ أبيضُ حولها — يُستعمل حين تقع على غلافٍ ملوّن.
  final double ring;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final letter = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    return Container(
      width: size + ring * 2,
      height: size + ring * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring > 0 ? AppColors.surface : Colors.transparent,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: url == null || url.isEmpty
              ? _letter(letter)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // وعطبُ الشبكة يعود إلى الحرف لا إلى أيقونةٍ مكسورة: الصورة
                  // زينةٌ والاسمُ هو الخبر.
                  errorBuilder: (_, _, _) => _letter(letter),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _letter(letter),
                ),
        ),
      ),
    );
  }

  Widget _letter(String letter) => Container(
    color: AppColors.accent.withValues(alpha: Tint.disc),
    alignment: Alignment.center,
    child: Text(
      letter,
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
        color: AppColors.accent,
      ),
    ),
  );
}

/// سطر «اسم: قيمة» بمحاذاة طرفَي البطاقة.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Muted(label),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.label = 'جارٍ التحميل…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.accent),
        const SizedBox(height: Space.md),
        Muted(label),
      ],
    ),
  );
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({super.key, required this.title, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionTitle(title),
          if (description != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7),
            ),
          ],
        ],
      ),
    ),
  );
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.critical, height: 1.7),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Space.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ],
      ),
    ),
  );
}

/// أيقونة القسم من `slug`.
///
/// من الـ`slug` لا من عمود `icon` في القاعدة: العمود موجودٌ لكنه فارغٌ في
/// البذرة، و`slug` معرّفٌ برمجيٌّ لا يُترجم ولا يُغيَّر بعد أن تُبنى عليه
/// بيانات — فهو الأثبت.
///
/// والافتراضيّ ليس زينة: من يضيف قسماً جديداً من اللوحة غداً يجد له أيقونةً
/// معقولة بدل فراغٍ في بطاقةٍ نصفُها فارغ.
IconData categoryIcon(String slug) => switch (slug) {
  'halls' => Icons.meeting_room_outlined,
  'catering' => Icons.restaurant_outlined,
  'artists' => Icons.music_note_outlined,
  'sound' => Icons.speaker_outlined,
  'photography' => Icons.photo_camera_outlined,
  'support' => Icons.water_drop_outlined,
  'cars' => Icons.directions_car_outlined,
  'attire' => Icons.checkroom_outlined,
  'planners' => Icons.event_note_outlined,
  'beauty' => Icons.brush_outlined,
  'decor' => Icons.local_florist_outlined,
  'printing' => Icons.print_outlined,
  _ => Icons.category_outlined,
};


/// صبغة القسم.
///
/// لونٌ لكل قسمٍ لا لونٌ واحد: صفٌّ من اثنتي عشرة بطاقةٍ بلونٍ واحد يُقرأ
/// كتلةً تُبحث بالقراءة، والصبغةُ تجعل كلَّ بطاقةٍ تُعرف قبل أن يُقرأ اسمها.
///
/// **وعائلةٌ دافئة لا قوسُ قزح:** كانت الاثنتا عشرة أزرقَ وبنفسجيّاً
/// وفيروزيّاً، فتُقرأ فوق الكريم كأنها من تطبيقٍ آخر لُصقت هنا. فنُقلت كلُّها
/// إلى جيرانِ النبيذيّ — طَفلٌ وصدأٌ وزيتونٌ وخُزاميّ — فتبقى كلُّ بطاقةٍ
/// تُعرف قبل أن يُقرأ اسمها، ويبقى الصفُّ كلُّه من عائلةٍ واحدة.
///
/// والاثنتا عشرة مقيسةٌ على أرضية البطاقة: أدناها ‎٥٫٥٥:١‎ وأعلاها ‎١٠٫٧٦:١‎
/// — فلا واحدةَ منها زينةٌ لا تُقرأ. وقياسٌ لا ذوق، لأن «يبدو واضحاً» على
/// شاشةِ من يكتب غيرُه في شمسِ من يستعمل.
Color categoryTone(String slug) => switch (slug) {
  'halls' => AppColors.accent,
  'catering' => const Color(0xFFA3521A),
  'artists' => const Color(0xFF6B2E8F),
  'sound' => const Color(0xFF14615F),
  'photography' => const Color(0xFFB01C5B),
  'support' => const Color(0xFF1F5D8C),
  'cars' => const Color(0xFF4A3F86),
  'attire' => const Color(0xFF93174A),
  'planners' => const Color(0xFF2F6B33),
  'beauty' => const Color(0xFF8E2270),
  'decor' => const Color(0xFFB23C12),
  'printing' => const Color(0xFF5F6B12),
  _ => AppColors.ink2,
};

/// بطاقة قسم — قرصٌ بأيقونته واسمُه تحته.
///
/// بطاقةٌ لا شريحة: الشريحة نصٌّ في إطار، وصفٌّ منها يُقرأ كتلةً واحدة يُبحث
/// فيها بالقراءة. والأيقونة تُعرف قبل أن يُقرأ الاسم، فيُمسح الصفُّ بالعين
/// مسحاً واحداً.
///
/// وارتفاعها ثابتٌ لا يتبع طول الاسم: «الموية والطليع والخدمات المساندة»
/// و«السيارات» في صفٍّ واحد، ولو تفاوت الارتفاع لتعرّج الصفّ كلّه.
class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.tone,
    this.width = 96,
    this.enterDelay = Duration.zero,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  /// صبغة البطاقة. تُترك فارغةً فتأخذ لون العلامة — وهو حال «الكل».
  final Color? tone;

  /// عرضٌ ثابت في الصفّ الأفقي، ويُترك للشبكة أن تملأه فيها.
  final double? width;

  /// تأخير ظهورها — يُمرَّر متدرّجاً فتدخل البطاقات تباعاً لا دفعةً واحدة.
  final Duration enterDelay;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _down = false;
  bool _shown = false;

  /// مؤقّت الدخول — يُحفظ ليُلغى.
  ///
  /// `Future.delayed` لا يُلغى: يبقى معلّقاً بعد زوال البطاقة ممسكاً بها،
  /// وإطارُ الاختبار يُسقط أي اختبارٍ يتركه («Pending timers») — وهو محقٌّ،
  /// فالتسريب واحدٌ في الحالتين. والمستخدم يمرّر الشبكة سريعاً فتُبنى
  /// بطاقاتٌ وتزول قبل أن يحين دخولها.
  Timer? _enter;

  @override
  void initState() {
    super.initState();
    // الدخول المتدرّج يُجدول لا يُحسب في البناء: `setState` أثناء البناء
    // ممنوع، والمؤقّت يضع التغيير في الإطار التالي.
    if (widget.enterDelay == Duration.zero) {
      _shown = true;
    } else {
      _enter = Timer(widget.enterDelay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void dispose() {
    _enter?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone ?? AppColors.accent;
    final active = widget.active;

    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        // تنزلق صاعدةً قليلاً عند الدخول: حركةٌ تدلّ على الترتيب، لا قفزة.
        offset: _shown ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _down ? 0.94 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.width,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.md,
                ),
                decoration: BoxDecoration(
                  // زجاجٌ مصبوغ: تدرّجٌ من أبيضَ شبه صافٍ إلى صبغةٍ خفيفة،
                  // فيبدو السطح ذا عمقٍ لا لوحةً مسطّحة.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      tone.withValues(alpha: active ? 0.16 : 0.07),
                    ],
                  ),
                  border: Border.all(
                    color: tone.withValues(alpha: active ? 0.55 : 0.18),
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    // ظلٌّ يُغلق عند الضغط فتبدو البطاقة وقد غاصت في مكانها.
                    BoxShadow(
                      color: tone.withValues(alpha: _down ? 0.10 : 0.18),
                      blurRadius: _down ? 4 : 12,
                      offset: Offset(0, _down ? 1 : 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tone.withValues(alpha: active ? 0.26 : 0.15),
                            tone.withValues(alpha: active ? 0.14 : 0.07),
                          ],
                        ),
                      ),
                      child: Icon(widget.icon, size: 19, color: tone),
                    ),
                    const SizedBox(height: Space.sm),
                    // ثلاثة أسطرٍ بحدٍّ أقصى ثم قصٌّ. وثلاثةٌ لا سطران: أطولُ
                    // اسمٍ في البذرة — «الموية والطليع والخدمات المساندة» —
                    // يُقصّ عند سطرين فيضيع آخره، ويكتمل عند ثلاثة.
                    Text(
                      widget.label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? tone : AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة اختيار — للأقسام والمحافظات.
class PickChip extends StatelessWidget {
  const PickChip({super.key, required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.surface,
        border: Border.all(color: active ? AppColors.accent : AppColors.hairline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: active ? AppColors.accentInk : AppColors.ink2,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// ارتفاع الشريط الزجاجي مع هامشه — تحتاجه القوائم لتُنهي محتواها فوقه.
///
/// ثابتٌ مشترك لا رقمٌ مكرّر: الشريط يطفو والمحتوى يمرّ تحته، فآخرُ بطاقةٍ في
/// أي قائمةٍ تختفي خلفه ما لم تُحسب هذه المسافة. ونسيانُها في شاشةٍ واحدة عيبٌ
/// لا يظهر إلا حين يصل المستخدم إلى آخر القائمة.
const double glassNavSpace = 96;

/// شريط تنقّلٍ سفليٌّ زجاجيّ يطفو فوق المحتوى.
///
/// **والأيقونات ليست بيضاء.** الزجاج أبيض والصفحة `#F4F7FC`، فأبيضُ على
/// أبيضَ يعطي ‎١٫٠٤:١‎ — أي لا شيء. فالمختار بلون العلامة وغيرُه رماديّ، وكلاهما
/// مقيسٌ على الزجاج نفسه لا مقدَّر. والزجاج الأبيض بأيقوناتٍ بيضاء إنما يصلح
/// فوق خلفيةٍ داكنة.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.index, required this.onSelect, required this.items});

  final int index;
  final ValueChanged<int> onSelect;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى ما تحته
            // كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _GlassNavCell(
                        item: items[i],
                        active: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _GlassNavCell extends StatelessWidget {
  const _GlassNavCell({required this.item, required this.active, required this.onTap});
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = active ? AppColors.accent : AppColors.ink2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // حبّةٌ مصبوغة تحت الأيقونة المختارة: علامةٌ ثانية غير اللون، فمن لا
          // يفرّق الألوان يعرف أين هو. والأيقونة مصمتةٌ للمختار ومفرَّغة لغيره
          // — علامةٌ ثالثة.
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(active ? item.activeIcon : item.icon, size: 21, color: tone),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: tone,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ),
    );
  }
}

/// حبّةٌ بعدد ما لم يُقرأ.
///
/// والعدد فيها لا نقطةٌ صمّاء: «٣» تقول إن ثمّة حديثاً يجري، والنقطة تقول
/// «شيءٌ ما». والحدُّ عند تسعة فـ«٩+» — رقمٌ من ثلاث خانات يمطّ الحبّة حتى
/// تكسر الصفّ الذي هي فيه.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w700,
          color: AppColors.accentInk,
        ),
      ),
    );
  }
}

/// أيقونةٌ في الشريط العلوي وعليها حبّةُ ما لم يُقرأ.
///
/// في الشريط العلوي لا في الشريط السفلي: بنوده الخمسة محدَّدة، وإضافةُ سادسٍ
/// تضيّق الخمسة كلَّها. والأيقونة هنا في المكان الذي تعوّده الناس من كل تطبيق.
class BadgeIconButton extends StatelessWidget {
  const BadgeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        // قرصٌ شفّافٌ تحت الأيقونة: هذا موضع الزجاجيّة — لا في لون الرمز.
        // فاللون مقيسٌ (‏`ink2`‏ يعطي ‎٧٫٥٨:١‎ على الزجاج و‎٤٫٥٥‎ حين تمرّ
        // البطاقة الزرقاء تحته)، والشكلُ حرّ.
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.55),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          foregroundColor: AppColors.ink2,
        ),
        icon: Icon(icon, size: 20),
      ),
      if (count > 0)
        // على ركن الرمز لا على حافّة الزرّ: صندوق `IconButton` ‎٤٨‎ بكسلاً
        // والرمز ‎٢٢‎ في وسطه، فحبّةٌ عند الحافّة تطفو على بُعد أحد عشر بكسلاً
        // منه — تُقرأ عائمةً لا تابعةً له، وتزدحم بجارتها حين يكون في الشريط
        // زرّان. وقد رُئي ذلك في الرسم لا في الشيفرة.
        Positioned(
          top: 5,
          left: 5,
          child: IgnorePointer(child: UnreadDot(count: count)),
        ),
    ],
  );
}

/// أيقونة المحادثات.
class ChatIconButton extends StatelessWidget {
  const ChatIconButton({super.key, required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BadgeIconButton(
    icon: Icons.forum_outlined,
    tooltip: 'المحادثات',
    count: unread,
    onTap: onTap,
  );
}

/// جرس الإشعارات.
class BellIconButton extends StatelessWidget {
  const BellIconButton({super.key, required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BadgeIconButton(
    icon: Icons.notifications_none_rounded,
    tooltip: 'الإشعارات',
    count: unread,
    onTap: onTap,
  );
}

/// ارتفاع الشريط العلوي الزجاجي مع هامشه — تحتاجه القوائم لتبدأ تحته.
///
/// نظيرُ `glassNavSpace` في الأعلى: الشريط يطفو والمحتوى يمرّ **تحته**، وهذا
/// هو ما يعطي التمويهَ ما يموّهه. فبلا هذه المسافة تبدأ أولُ بطاقةٍ خلف
/// الزجاج ولا تُقرأ.
const double glassHeaderBar = 56;
const double glassHeaderSpace = glassHeaderBar + Space.sm + Space.md;

/// المسافة الكاملة من أعلى الشاشة: شريط الحالة ثم الزجاج.
double glassHeaderTop(BuildContext context) =>
    MediaQuery.paddingOf(context).top + glassHeaderSpace;

/// شريطٌ علويٌّ زجاجيٌّ يطفو فوق المحتوى.
///
/// **والأيقونات ليست بيضاء** — كما في الشريط السفلي، وللسبب نفسه مقيساً:
/// الزجاج أبيض بشفافية ‎٠٫٧٢‎ والصفحة `#F4F7FC`، فما يظهر خلفه ‎#FCFDFE‎.
/// والأبيض عليه يعطي **‎١٫٠٢:١‎** — أي لا شيء. وحتى حين تمرّ بطاقةُ الخطة
/// الزرقاء تحته فيصير ‎#BDC6E3‎، يبقى الأبيض عند ‎١٫٧٠:١‎.
///
/// وأزرقُ العلامة نفسه لا يصلح للأيقونات هنا: ‎٦٫٥٧:١‎ فوق الصفحة، لكنه يهبط
/// إلى **‎٣٫٩٥:١‎** حين تمرّ البطاقة الزرقاء تحته — وهو ما يقع في الشاشة
/// الأولى كلَّما مُرِّرت. فالحبر ‎#0B1220‎ للعنوان و`ink2` للأيقونات: ‎١٨٫٣٦‎
/// و‎٧٫٥٨‎ فوق الصفحة، و‎١١٫٠٣‎ و‎٤٫٥٥‎ فوق البطاقة.
///
/// والزجاجيّةُ تبقى حيث تُرى: التمويه، والحدُّ الأبيض الرقيق، والزوايا، وقرصٌ
/// شفّافٌ تحت كل أيقونة.
class GlassHeader extends StatelessWidget {
  const GlassHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // التمويه هو ما يجعله زجاجاً لا لوناً شفّافاً: بدونه يُرى ما تحته
            // كما هو، فيبدو الشريط ورقةً باهتة لا سطحاً.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: glassHeaderBar,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ),
                  ...actions,
                  // ‎١٢‎ لا ‎٤‎: الشريط مقصوصٌ بزاويةٍ نصفُ قطرها ‎٢٤‎، وأقصى
                  // أيقونةٍ تقع في منحنى الزاوية — فحبّةُ عددها تُقصّ. رُئي
                  // في الرسم مكبَّراً لا في الشيفرة.
                  const SizedBox(width: Space.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
