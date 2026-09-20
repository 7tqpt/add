#!/usr/bin/env bash
# ضوابطُ سالبةٌ لتتابع القوائم وسحبِها للتحديث.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُحرس هنا فهرسٌ ثابت.** الأداةُ تبقى في الشجرة والاختبارُ
# الساذجُ يجدها ويطمئنّ، والقائمةُ تظهر دفعةً واحدةً كما كانت — لا فرقَ
# تراه العينُ إلّا بالمقارنة.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/list_motion_test.dart"

H=lib/src/screens/home.dart
F=lib/src/screens/favourites.dart
N=lib/src/screens/notifications.dart
P=lib/src/screens/plan.dart
V=lib/src/screens/provider_public.dart
S=lib/src/screens/services.dart
E=lib/src/screens/explore.dart

FILES=("$H" "$F" "$N" "$P" "$V" "$S" "$E")
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

echo; echo "== تتابعُ الشاشات الستّ =="

run "(أ) الرئيسيةُ تقع دفعةً واحدة" \
  sub "$H" \
"                FadeSlideIn(index: 0, child: _Banners(banners: data.banners))," \
"                _Banners(banners: data.banners),"

run "(ب) المفضّلةُ تقع دفعةً واحدة" \
  sub "$F" \
"                FadeSlideIn(
                  index: i," \
"                FadeSlideIn(
                  index: 0,"

run "(ج) الإشعاراتُ تقع دفعةً واحدة" \
  sub "$N" \
"                return FadeSlideIn(
                  index: i," \
"                return FadeSlideIn(
                  index: 0,"

run "(د) خطّةُ العرس تقع دفعةً واحدة" \
  sub "$P" \
"                FadeSlideIn(index: 0, child: _ProgressCard(progress: progress)),
                const SizedBox(height: Space.md),
                FadeSlideIn(index: 1, child: _Tiles(plan: p, progress: progress))," \
"                FadeSlideIn(index: 0, child: _ProgressCard(progress: progress)),
                const SizedBox(height: Space.md),
                FadeSlideIn(index: 0, child: _Tiles(plan: p, progress: progress)),"

run "(هـ) خدماتُ المزوّد تقع دفعةً واحدة" \
  sub "$V" \
"              FadeSlideIn(
                index: i," \
"              FadeSlideIn(
                index: 0,"

echo; echo "== السحبُ للتحديث =="

run "(و) «خدماتي» بلا سحب" \
  sub "$S" \
"          return RefreshIndicator(
            onRefresh: () async => _reload()," \
"          return RefreshIndicator(
            onRefresh: () async {},"

run "(ز) «استكشف» بلا سحب" \
  sub "$E" \
"                onRefresh: () async {
                  _reload();
                  await _loadFavourites();
                }," \
"                onRefresh: () async {},"

# ── ح) وسحبُ «استكشف» يُحدّث النتائجَ ويترك القلوب ────────────────────────
#
# القلوبُ المملوءةُ تأتي من نداءٍ آخر — فيُري صاحبَه محفوظاً لم يعد محفوظاً.
run "(ح) «استكشف» لا تقرأ المفضّلة" \
  sub "$E" \
"                onRefresh: () async {
                  _reload();
                  await _loadFavourites();
                }," \
"                onRefresh: () async => _reload(),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
