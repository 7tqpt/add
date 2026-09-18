#!/usr/bin/env bash
# ضوابطُ سالبةٌ لتغييرين: حقلُ «القسم» منسدلةً، وصورُ المعرض قابلةً للضغط.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/service_category_dropdown_test.dart test/gallery_photo_tap_test.dart"

S=lib/src/screens/services.dart
P=lib/src/screens/provider_public.dart
A=lib/src/data/api.dart

FILES=("$S" "$P" "$A")
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

echo; echo "== ضوابطُ حقل القسم =="

# ── أ) يعود شريطُ الشرائح ───────────────────────────────────────────────────
run "(أ) عودةُ شريط الشرائح" \
  sub "$S" \
"                return DropdownButtonFormField<String>(" \
"                return Wrap(children: [for (final c in rows) PickChip(label: c.name, active: _categoryId == c.id, onTap: () => setState(() => _categoryId = c.id))]); // ignore: dead_code
                return DropdownButtonFormField<String>("

# ── ب) والاختيارُ لا يصل الحالَ فلا يصل الخادم ──────────────────────────────
#
# **وهذا أخطرُها لأنّه لا يُرى عطباً**: `DropdownButtonFormField` حقلُ نموذجٍ
# يحتفظ باختياره داخلَ نفسه، فيعرضه للعين كاملاً — والخادمُ لا يصله شيء.
# وهو بعينه ما يمرّ لو قيس ما تعرضه الشاشةُ بدل ما وصل.
run "(ب) الاختيارُ لا يصل الخادم" \
  sub "$S" \
"                  onChanged: (v) => setState(() => _categoryId = v)," \
"                  onChanged: (v) {},"

# ── ج) ويُوضع الاسمُ في القيمة بدل المعرّف ──────────────────────────────────
#
# يمرّ في العين تماماً، ثمّ يصل الخادمَ نصّاً عربيّاً بدل `uuid` فيُرفض.
run "(ج) الاسمُ بدل المعرّف" \
  sub "$S" \
"                        value: c.id," \
"                        value: c.name,"

echo; echo "== ضوابطُ صور المعرض =="

# ── د) وتعود الصورةُ ثابتةً لا تستجيب ───────────────────────────────────────
run "(د) لا مستمعَ ضغطٍ على الصورة" \
  sub "$P" \
"          itemBuilder: (context, i) => GestureDetector(
            key: ValueKey('gallery-photo-tap-\$i'),
            onTap: () => openPhoto(context, url: Api.mediaUrl(items[i].path))," \
"          itemBuilder: (context, i) => GestureDetector(
            key: ValueKey('gallery-photo-tap-\$i'),
            onTap: () {},"

# ── هـ) وتُفتح الصورةُ الأولى مهما ضُغط ─────────────────────────────────────
#
# **ولا يُرى عطباً في شبكةٍ صورُها متشابهة**: العارضُ يُفتح، والضغطةُ
# تستجيب، والصورةُ خطأ. ولا يكشفه إلّا سؤالُ العارض عن رابطه.
run "(هـ) الصورةُ الأولى مهما ضُغط" \
  sub "$P" \
"            onTap: () => openPhoto(context, url: Api.mediaUrl(items[i].path))," \
"            onTap: () => openPhoto(context, url: Api.mediaUrl(items[0].path)),"

# ── و) ويُعرض «تغيير» على من لا يملك الصورة ─────────────────────────────────
#
# زرٌّ يُضغط فيرتدّ عليه الطلبُ بخطأٍ لا يفهمه — وهو عميلٌ يرى صورةَ غيره.
run "(و) «تغيير» لمن لا يملكها" \
  sub "$P" \
"            onTap: () => openPhoto(context, url: Api.mediaUrl(items[i].path))," \
"            onTap: () => openPhoto(context, url: Api.mediaUrl(items[i].path), onEdit: () {}),"

# ── ز) ويُبتلع الرابطُ في الطريق ────────────────────────────────────────────
#
# **ولولا `mediaUrlOverride` لَما سقط هذا**: بلا خادمٍ يعود `mediaUrl`
# بـ`null` أبداً، و`openPhoto` لا تفتح لرابطٍ فارغ — فتبقى الحزمةُ خضراءَ
# والوصلةُ مقطوعة. وهو الدرسُ نفسُه الذي عُلِّم في قرص المحادثات.
run "(ز) الرابطُ لا يصل العارض" \
  sub "$A" \
"    final fake = mediaUrlOverride;
    if (fake != null) return fake(path);" \
"    final fake = mediaUrlOverride;
    if (fake != null) return null;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
