#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تغيير القسم» وخدماتٍ خارج أقسام صاحبها — `test/provider_categories.test.ts`،
# ثمّ المقيسُ في المتصفّح (`tool/dashboard_shots.mjs`). تكسر كلَّ ضمانةٍ مرّةً
# بشيفرةٍ صالحة، وتتأكّد أنّ ما يقيسها يحمرّ، وتطبع ما سقط.
set -uo pipefail
cd "$(dirname "$0")/.."

FILES="src/services/directory.ts src/pages/ProviderDetail.tsx src/data/mock.ts"
BACKUP=$(mktemp -d)
for f in $FILES; do mkdir -p "$BACKUP/$(dirname "$f")"; cp "$f" "$BACKUP/$f"; done
restore() { for f in $FILES; do cp "$BACKUP/$f" "$f"; done; }
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
  local kind="$1" name="$2"; shift 2
  restore
  if ! "$@"; then echo "✗ $name — لم يقع الكسر"; FAIL=$((FAIL+1)); restore; return; fi
  local out green
  if [ "$kind" = unit ]; then
    out=$(npx vitest run test/provider_categories.test.ts 2>&1)
    echo "$out" | grep -qE "Tests +[0-9]+ passed \(" && green=1 || green=0
  else
    if ! npm run build >/dev/null 2>&1; then
      echo "✗ $name — البناءُ سقط، فالمقيسُ نسخةٌ قديمة"; FAIL=$((FAIL+1)); restore; return
    fi
    out=$(SHOTS="$BACKUP/shots" node tool/dashboard_shots.mjs 2>&1)
    echo "$out" | grep -q "كلُّ ما قيس أخضر" && green=1 || green=0
  fi
  if [ "$green" = 1 ]; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "^ +×|^❌" | sort -u | head -3 | sed 's/^/   /'
    PASS=$((PASS+1))
  fi
  restore
}

# ── أ) الخدمةُ خارج أقسامه لا تُعلَّم — فتبدو للإدارة ظاهرةً وهي مخفيّة ──────
run unit "(أ) المخفيّةُ لا تُعدّ" sub src/services/directory.ts \
  ") => !provider.categories.includes(service.category_name)" \
  ") => !provider.categories.includes(service.category_name) && false"

run unit "(ب) يُحفظ بلا قسم" sub src/services/directory.ts \
  "  if (categories.length === 0) throw new Error('اختر قسماً واحداً على الأقلّ.')" \
  ""

run unit "(ج) وضعُ العرض بلا خدمةٍ خارج قسمها" sub src/data/mock.ts \
  "      ...(i === 0 && t === 1 && categoryId !== photo.id" \
  "      ...(i === -1 && t === 1 && categoryId !== photo.id"

run browser "(د) الشارةُ تقول «معروضة» لمخفيّة" sub src/pages/ProviderDetail.tsx \
  "                            {isOutsideCategories(service, record) ? (
                              <Badge tone=\"critical\" icon={false}>" \
  "                            {false ? (
                              <Badge tone=\"critical\" icon={false}>"

run browser "(هـ) النافذةُ لا تقول ما يعود" sub src/pages/ProviderDetail.tsx \
  "  const wouldReturn = outside.filter((s) => pickedNames.includes(s.category_name)).length" \
  "  const wouldReturn = 0"

run browser "(و) الحفظُ لا يعيد تحميل المزوّد" sub src/pages/ProviderDetail.tsx \
  "      provider.reload()
      portfolio.reload()
    } catch (cause) {
      setCategoriesError" \
  "      portfolio.reload()
    } catch (cause) {
      setCategoriesError"

run browser "(ز) «تغيير القسم» لكلّ دور" sub src/pages/ProviderDetail.tsx \
  "                disabled={busy || !canWrite || !allCategories.data}" \
  "                disabled={busy || !allCategories.data}"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
