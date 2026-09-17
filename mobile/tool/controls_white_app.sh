#!/usr/bin/env bash
# ضوابطُ سالبةٌ لبياض التطبيق كلِّه.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وهذه الضوابطُ انقلبت ولم تُحذف.** كانت تحرس ألّا تُبدَّل الثيمة — إذ كان
# المطلوبُ شاشتين لا غير — فلمّا طلب صاحبُ المنصّة التطبيقَ كلَّه صارت تحرس
# العكس. والحُجّةُ الأولى مكتوبةٌ في رأس `test/white_app_test.dart` لا تُمحى.
#
# **وأخطرُ ما يُكسر هنا (ج): يعود الفاصلُ بلون الأرضيّة.** وهو كسرٌ **لا
# يُرى في أيّ لقطةٍ لأنّه اختفاء**: تلتصق أقسامُ «حسابي» بلا خطٍّ يفصلها،
# ولا شيءَ يبدو معطوباً.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/white_app_test.dart"

C=lib/src/screens/conversations.dart
T=lib/src/core/theme.dart
K=lib/src/ui/kit.dart

FILES=("$C" "$T" "$K")
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

# ── أ) تعود الأرضيّةُ ورديّةً من الثيمة ─────────────────────────────────────
#
# وهو ردُّ التغيير كلِّه — فيجب أن يسقط من الشاشتين ومن الافتراضيّ جميعاً.
run "(أ) تعود الأرضيّةُ ورديّة" \
  sub "$T" "    scaffoldBackgroundColor: AppColors.surface," \
           "    scaffoldBackgroundColor: AppColors.page,"

# ── ب) وتكتب الشاشةُ بياضَها بيدها ──────────────────────────────────────────
#
# **وهذا كسرٌ يبدو سليماً**: الشاشةُ بيضاءُ فيمرّ شرطُ لونها. لكنّه يُخفي
# تبدّلَ الثيمة — تعود ورديّةً يوماً وتبقى هاتان بيضاوين وحدَهما.
run "(ب) «المحادثات» تكتب لونَها بيدها" \
  sub "$C" "    return Scaffold(" \
           "    return Scaffold(
      backgroundColor: AppColors.surface,"

# ── ج) ويعود الفاصلُ بلون الأرضيّة ──────────────────────────────────────────
#
# **وهذا أخطرُها لأنّه اختفاءٌ لا عطب.** `MenuGap` كان `AppColors.page`، فلمّا
# ابيضّت الأرضيّةُ صار أبيضَ على أبيض: تلتصق «أريد تقديم خدمة» بـ«الإعدادات»
# ولا شيءَ يبدو مكسوراً. **ولا تُسقطه لقطةٌ** — تُسقطه المقارنةُ بالأرضيّة.
run "(ج) الفاصلُ بلون الأرضيّة" \
  sub "$K" "      Container(height: Space.sm, color: AppColors.surface2);" \
           "      Container(height: Space.sm, color: AppColors.surface);"

# ── د) ويتبع الفاصلُ الأرضيّةَ أيّاً كانت ───────────────────────────────────
#
# كسرٌ أخبثُ من (ج): لا يسمّي الأبيضَ بل يسأل الثيمةَ — فيختفي اليومَ ويختفي
# غداً مهما تبدّلت الأرضيّة.
run "(د) الفاصلُ يتبع الأرضيّة" \
  sub "$K" "  Widget build(BuildContext context) =>
      Container(height: Space.sm, color: AppColors.surface2);" \
           "  Widget build(BuildContext context) => Container(
        height: Space.sm,
        color: Theme.of(context).scaffoldBackgroundColor,
      );"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
