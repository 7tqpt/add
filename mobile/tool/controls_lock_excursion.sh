#!/usr/bin/env bash
# ضوابطُ سالبةٌ لإعفاء الرحلة من القفل.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا كسران متضادّان، وكلاهما لازم:**
#
#   ــ (أ) يُلغى الإعفاء، فيعود العطلُ الذي شُكي منه: «يخرجني التطبيق ولم
#     يتغيّر شيء».
#
#   ــ (د) يُوسَّع الإعفاء حتى يبتلع القفلَ كلَّه — وهو أخطرُ من العطل: قفلٌ
#     يُرى في الإعدادات ولا يقفل. **ولولاه لَمرّ إصلاحٌ يُلغي الحماية.**
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

# **وحزمتان لا واحدة.** الإعفاءُ في `lock_excursion`، وما حوله من فرضِ
# القفل في `force_lock` — وكسرٌ يفتح البابَ على مصراعيه يجب أن يُسقط
# الثانية أيضاً.
SUITE="test/lock_excursion_test.dart test/force_lock_test.dart"

L=lib/src/core/app_lock.dart
P=lib/src/ui/pick_image.dart

FILES=("$L" "$P")
BACKUP=$(mktemp -d)
for i in "${!FILES[@]}"; do cp "${FILES[$i]}" "$BACKUP/$i"; done
restore() { for i in "${!FILES[@]}"; do cp "$BACKUP/$i" "${FILES[$i]}"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT
PASS=0; FAIL=0

sub() {
  local file="$1" old="$2" new="$3" n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1; fi
  python3 - "$file" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
}

run() {
  local name="$1"; shift
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  if timeout 600 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 600 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) يُلغى الإعفاءُ فيعود العطل ───────────────────────────────────────────
run "(أ) يعود القفلُ على كلّ عودة" \
  sub "$L" \
"    if (_inExcursion()) {
      _left = false;
      return;
    }" \
"    // كُسر"

# ── ب) وتُنسى الرحلةُ في المنتقي ────────────────────────────────────────────
#
# **ولا يسقط هذا بسؤال «أيوجد إعفاء؟»** — الإعفاءُ موجودٌ في `AppLock`،
# والمنتقي وحدَه لا يستعمله. يسقط لأنّ الشجرةَ تُسأل بعد رحلةٍ حقيقيّة.
run "(ب) المنتقي بلا رحلة" \
  sub "$P" \
"  final file = await awayFromApp(
    () => ImagePicker().pickImage(" \
"  final file = await Future.value(
    () => ImagePicker().pickImage("

# ── ج) ولا حدَّ زمنيَّ للرحلة ───────────────────────────────────────────────
#
# **وهو اختيارُ صاحب المنصّة.** رحلةٌ بلا حدٍّ تعني أنّ من ترك المعرضَ وذهب
# يعود إلى حسابٍ مفتوح.
run "(ج) الرحلةُ بلا مهلة" \
  sub "$L" \
"    return at != null && lockClock().difference(at) <= lockExcursionGrace;" \
"    return at != null;"

# ── د) ويتّسع الإعفاءُ فيبتلع القفل ─────────────────────────────────────────
#
# **وهذا أخطرُ من العطل نفسِه.** رحلةٌ مفتوحةٌ أبداً = قفلٌ لا يقفل. ولولا
# هذا الضابطِ لَمرّ «إصلاحٌ» يُلغي الحماية وهي تبدو قائمةً في الإعدادات.
run "(د) رحلةٌ مفتوحةٌ أبداً" \
  sub "$L" \
"  bool _inExcursion() {
    if (_excursions == 0) return false;" \
"  bool _inExcursion() {
    if (_excursions == 0) return true;"

# ── هـ) والرحلةُ لا تنتهي بسقوط العمل ───────────────────────────────────────
#
# `finally` تصير `then`: فخطأٌ عابرٌ في المنتقي يترك القفلَ معطَّلاً حتى
# تنقضي مهلتُه.
run "(هـ) رحلةٌ لا تنتهي بالخطأ" \
  sub "$L" \
"  try {
    return await body();
  } finally {
    appLock.endExcursion();
  }" \
"  final out = await body();
  appLock.endExcursion();
  return out;"

# ── و) وترث الرحلةُ الجديدةُ لحظةَ بدء المهجورة ─────────────────────────────
#
# **وهذا الضابطُ وُلد من ضابطٍ لم يسقط.** كُتب أوّلاً كسرٌ يمنع «نسيانَ»
# الرحلة المنقضية في `_inExcursion`، **فبقيت الحزمةُ خضراء** — والعلّةُ أنّ
# النسيانَ لا يغيّر شيئاً يُرى: `_excursionAt` لا يتقدّم، فما انقضى يبقى
# منقضياً. فحُذف السطران ولم يُدَّعَ لهما حرز.
#
# **لكنّ الكسرَ كشف عيباً حقيقيّاً بجوارهما:** لو ورثت الرحلةُ الجديدةُ لحظةَ
# بدء رحلةٍ مهجورةٍ لَوُلدت منقضية، فيعود العطلُ بعينه — يفتح معرضَه فيُلقى
# على شاشة الرمز. وهذا ما يكسره هذا الضابط.
run "(و) الجديدةُ ترث لحظةَ المهجورة" \
  sub "$L" \
"    final at = _excursionAt;
    if (at == null || lockClock().difference(at) > lockExcursionGrace) {
      // ما مضى مهجورٌ لا يُحتسب: تبدأ الرحلةُ من الآن ووحدَها.
      _excursions = 0;
      _excursionAt = lockClock();
    }
    _excursions++;" \
"    _excursions++;
    _excursionAt ??= lockClock();"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
