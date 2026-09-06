#!/usr/bin/env bash
# ضوابطُ سالبةٌ لكلمات الإعلان وصورِه المتعدّدة.
#
# كلُّ ضابطٍ يكسر ضمانةً واحدةً في الشيفرة الحيّة ثمّ يشغّل الحزمة: إن بقيت
# خضراءَ فالحارسُ لا يحرس. والملفّاتُ تُعاد كما كانت في كلّ حال.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/polish_test.dart

FILES=(lib/src/screens/home.dart lib/src/data/models.dart)
BACKUP=$(mktemp -d)
for f in "${FILES[@]}"; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in "${FILES[@]}"; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT

PASS=0; FAIL=0

sub() {
  local file="$1" old="$2" new="$3" n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then
    echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1
  fi
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

H=lib/src/screens/home.dart
M=lib/src/data/models.dart

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
  echo "أخضر."
else
  echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1
fi

echo
echo "== الضوابط =="

# أ) الكلماتُ لا تُكتب أصلاً — الصورةُ وحدَها كما كانت.
run "أ) لافتةٌ بلا كلمات" sub "$H" \
  '          if (banner.headline.isNotEmpty)
            PositionedDirectional(
              start: 14,' \
  '          if (false)
            PositionedDirectional(
              start: 14,'

# ب) كلماتٌ بلا ستار — أبيضُ على صورةِ قاعةٍ نهاراً لا يُقرأ حرفاً.
run "ب) كلماتٌ بلا ستار" sub "$H" \
  '          if (banner.headline.isNotEmpty)
            Positioned.fill(' \
  '          if (false)
            Positioned.fill('

# ج) ستارٌ يُرسم دائماً — فلافتةٌ بلا كلماتٍ يُظلَّم ثلثُها بلا سبب.
run "ج) ستارٌ على ما لا كلماتٍ له" sub "$H" \
  '          if (banner.headline.isNotEmpty)
            Positioned.fill(' \
  '          if (true)
            Positioned.fill('

# د) نصٌّ غامقٌ على ستارٍ غامق.
run "د) كلماتٌ بلون الحبر على الستار" sub "$H" \
  '                  color: Colors.white,
                  fontFamilyFallback: arabicFallback,' \
  '                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,'

# هـ) بلا حدٍّ للأسطر — نصٌّ طويلٌ يزحف حتى يغطّي الصورةَ التي دُفع ثمنُها.
run "هـ) كلماتٌ بلا حدِّ أسطر" sub "$H" \
  '                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,' \
  '                maxLines: null,
                style: const TextStyle(
                  fontSize: 16,'

# و) الطرازُ يُسقط الكلمات — تصل من القاعدة ولا تبلغ الشاشة.
run "و) الطرازُ لا يقرأ الكلمات" sub "$M" \
  "    headline: (m['headline'] ?? '') as String," \
  "    headline: ''," ''

echo
echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
