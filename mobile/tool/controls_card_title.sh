#!/usr/bin/env bash
# ضوابطُ سالبةٌ لعنوان البطاقة النبيذيّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (ج): شاشةٌ واحدةٌ تُنسى.** طلبهما معاً — «كذا لك في
# الطلبات نفس شيء» — واختبارٌ يقيس «خدماتي» وحدَها يمرّ وقد بقيت «الطلبات»
# بيضاءَ شهوراً.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/card_title_test.dart
K=lib/src/ui/kit.dart
S=lib/src/screens/services.dart
R=lib/src/screens/requests.dart
T=lib/src/core/theme.dart

BACKUP=$(mktemp -d)
cp "$K" "$BACKUP/k"; cp "$S" "$BACKUP/s"; cp "$R" "$BACKUP/r"; cp "$T" "$BACKUP/t"
restore() {
  cp "$BACKUP/k" "$K"; cp "$BACKUP/s" "$S"
  cp "$BACKUP/r" "$R"; cp "$BACKUP/t" "$T"
}
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) الشريطُ يعود بلا لون ─────────────────────────────────────────────────
#
# وهي الحالُ التي كانت: عنوانٌ أسودُ على أبيض.
run "(أ) الشريطُ بلا لونٍ نبيذيّ" \
  sub "$K" \
"      color: AppColors.accent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(" \
"      borderRadius: BorderRadius.circular(12),
    ),
    child: Row("

# ── ب) واللونُ يُبدَّل بلونٍ آخرَ لا يُشال ──────────────────────────────────
#
# كسرٌ أخبث: السطرُ مكتوبٌ والقيمةُ خطأ — فيمرّ على من ينظر إلى وجود السطر.
run "(ب) الشريطُ بلونٍ آخر" \
  sub "$K" \
"      color: AppColors.accent,
      borderRadius: BorderRadius.circular(12)," \
"      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),"

# ── ج) والحبرُ يعود أسود ────────────────────────────────────────────────────
run "(ج) العنوانُ بحبرٍ داكنٍ على النبيذيّ" \
  sub "$K" \
"            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.accentInk,
            )," \
"            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),"

# ── د) و«خدماتي» تُترك كما كانت ─────────────────────────────────────────────
run "(د) «خدماتي» بلا شريط" \
  sub "$S" \
"                  CardTitleBar(
                    s.title,
                    badge: s.isActive ? tr('معروضة') : tr('موقوفة'),
                  )," \
"                  SectionTitle(s.title),"

# ── هـ) و«الطلبات» تُنسى ────────────────────────────────────────────────────
#
# **وهذا أخطرُها.** «كذا لك في الطلبات نفس شيء» — طلبهما معاً. وحارسٌ يقيس
# شاشةً واحدةً يمرّ والأخرى بيضاء.
run "(هـ) «الطلبات» تُنسى" \
  sub "$R" \
"                  CardTitleBar(
                    b.serviceTitle,
                    badge: bookingStatusLabel(b.status),
                  )," \
"                  Text(b.serviceTitle),"

# ── و) والشارةُ تُشال من الشريط ─────────────────────────────────────────────
#
# اللونُ ذهب في هذا الشكل، فما بقي يقول «موقوفة» إلّا الكلمة.
run "(و) لا شارةَ في «خدماتي»" \
  sub "$S" \
"                    badge: s.isActive ? tr('معروضة') : tr('موقوفة')," \
"                    badge: null,"

run "(ز) لا شارةَ في «الطلبات»" \
  sub "$R" \
"                    badge: bookingStatusLabel(b.status)," \
"                    badge: null,"

# ── ح) والنبيذيُّ يُفتَّح حتى لا يُقرأ عليه الأبيض ──────────────────────────
#
# **ولا يُقاس اللونُ وحدَه بل ما يُقرأ عليه.** لونٌ يُسمّى `accent` ويُبدَّل
# يوماً إلى نبيذيٍّ فاتحٍ يُبقي كلَّ ما فوق أخضرَ، والحبرُ الأبيضُ عليه
# يذوب.
run "(ح) النبيذيُّ يُفتَّح فيذوب الأبيضُ عليه" \
  sub "$T" \
"  static const accent = Color(0xFF7B0F2E);" \
"  static const accent = Color(0xFFD98BA5);"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
