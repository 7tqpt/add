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
  const Muted(this.text, {super.key, this.size = 12});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
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
        Icon(Icons.star_rounded, size: size + 4, color: AppColors.warning),
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
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
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

/// بطاقة قسم — قرصٌ بأيقونته واسمُه تحته.
///
/// بطاقةٌ لا شريحة: الشريحة نصٌّ في إطار، وصفٌّ منها يُقرأ كتلةً واحدة يُبحث
/// فيها بالقراءة. والأيقونة تُعرف قبل أن يُقرأ الاسم، فيُمسح الصفُّ بالعين
/// مسحاً واحداً.
///
/// وارتفاعها ثابتٌ لا يتبع طول الاسم: «الموية والطليع والخدمات المساندة»
/// و«السيارات» في صفٍّ واحد، ولو تفاوت الارتفاع لتعرّج الصفّ كلّه.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = active ? AppColors.accent : AppColors.ink2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.md),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.accent : AppColors.hairline,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: active ? 0.14 : 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: tone),
            ),
            const SizedBox(height: Space.sm),
            // ثلاثة أسطرٍ بحدٍّ أقصى ثم قصٌّ. وثلاثةٌ لا سطران: أطولُ اسمٍ
            // في البذرة — «الموية والطليع والخدمات المساندة» — يُقصّ عند
            // سطرين فيضيع آخره، ويكتمل عند ثلاثة. والكلفة اثنا عشر بكسلاً
            // في ارتفاع الصفّ كلّه، وقد قِيست بالرسم لا بالتقدير.
            Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.accent : AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ],
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
