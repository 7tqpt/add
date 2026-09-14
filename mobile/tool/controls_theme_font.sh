#!/usr/bin/env bash
# ضوابطُ سالبةٌ لخطّ الأزرار وشريطِ التنقّل.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/theme_font_test.dart
T=lib/src/core/theme.dart

BACKUP=$(mktemp -d)
cp "$T" "$BACKUP/t"
restore() { cp "$BACKUP/t" "$T"; }
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

# ── أ) الزرُّ المملوءُ يعود بلا عائلة ────────────────────────────────────────
#
# وهي الحالُ التي كانت: الكلماتُ بخطّ العلامة والفراغاتُ بينها بخطّ النظام.
run "(أ) الزرُّ المملوءُ بلا fontFamily" \
  sub "$T" \
"        // والشرطةُ «—» لا يملكها خطُّ النظام كذلك، فكانت تخرج مربّعاً.
        fontFamily: brandFont," \
"        // والشرطةُ «—» لا يملكها خطُّ النظام كذلك، فكانت تخرج مربّعاً."

# ── ب) والمحاطُ كذلك ────────────────────────────────────────────────────────
run "(ب) الزرُّ المحاطُ بلا fontFamily" \
  sub "$T" \
"        // العلّةُ نفسُها التي في الزرّ المملوء أعلاه — وشرحُها هناك.
        fontFamily: brandFont," \
"        // العلّةُ نفسُها التي في الزرّ المملوء أعلاه — وشرحُها هناك."

# ── ج) وشريطُ التنقّل — وهو في كلّ شاشة ─────────────────────────────────────
run "(ج) شريطُ التنقّل بلا fontFamily" \
  sub "$T" \
"          // العلّةُ نفسُها التي في الأزرار — وهذه تُرى في كلّ شاشة.
          fontFamily: brandFont," \
"          // العلّةُ نفسُها التي في الأزرار — وهذه تُرى في كلّ شاشة."

# ── د) والاحتياطُ يُشال من خلفها ────────────────────────────────────────────
#
# **والعائلةُ وحدَها لا تكفي.** النسخُ يغطّي ما لا يغطّيه Plex من محارف،
# فبلا الاحتياط يختفي نصٌّ بلا رسالة.
run "(د) الاحتياطُ يُشال من الزرّ المملوء" \
  sub "$T" \
"        fontFamily: brandFont,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    ),
    outlinedButtonTheme:" \
"        fontFamily: brandFont,
        ),
      ),
    ),
    outlinedButtonTheme:"

# ── هـ) والعائلةُ تُبدَّل بخطٍّ آخرَ لا تُشال ───────────────────────────────
#
# كسرٌ أخبث: الحرفُ مكتوبٌ والقيمةُ خطأ — فيمرّ على من ينظر إلى وجود السطر.
run "(هـ) العائلةُ خطٌّ آخر" \
  sub "$T" \
"        // والشرطةُ «—» لا يملكها خطُّ النظام كذلك، فكانت تخرج مربّعاً.
        fontFamily: brandFont," \
"        // والشرطةُ «—» لا يملكها خطُّ النظام كذلك، فكانت تخرج مربّعاً.
        fontFamily: 'NotoNaskhArabic',"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
