#!/usr/bin/env bash
# ضوابطُ سالبةٌ لتبويب «الرسائل» وعدّاده ورأسِه.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/provider_chat_tab_test.dart test/provider_shell_nav_test.dart"

P=lib/src/screens/provider_shell.dart
C=lib/src/screens/conversations.dart
K=lib/src/ui/kit.dart

FILES=("$P" "$C" "$K")
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

echo; echo "== ضوابطُ التبويب =="

# ── أ) يعود ترتيبُ البنود إلى ما كان ───────────────────────────────────────
run "(أ) الترتيبُ يتبدّل" \
  sub "$P" \
"      tr('الطلبات'),
      tr('خدماتي'),
      tr('تقويمي')," \
"      tr('الطلبات'),
      tr('تقويمي'),
      tr('خدماتي'),"

# ── ب) ويجتمع رأسانِ في الشاشة ─────────────────────────────────────────────
#
# شريطُ المحادثات الخاصُّ تحت الرأس الزجاجيّ — وهو ما يقع لو أُدخلت الشاشةُ
# تبويباً بلا إسقاط شريطها.
run "(ب) رأسانِ في شاشة" \
  sub "$C" \
"      appBar: widget.embedded ? null : AppBar(title: Text(tr('المحادثات')))," \
"      appBar: AppBar(title: Text(tr('المحادثات')),"

echo; echo "== ضوابطُ الرأس =="

# ── ج) وتبقى أيقونةُ الرسائل في الرأس مع البند ─────────────────────────────
#
# بابان لغرفةٍ واحدةٍ يُحتار فيهما.
run "(ج) بابانِ للرسائل" \
  sub "$P" \
"          end: BellIconButton(unread: _alerts, onTap: _openAlerts)," \
"          start: BellIconButton(unread: _alerts, onTap: _openAlerts),
          end: ChatIconButton(unread: _unread, onTap: () {}),"

echo; echo "== ضوابطُ العدّاد =="

# ── د) ويذهب العدّادُ عن البند ─────────────────────────────────────────────
#
# **وهذا أخطرُها**: أيقونةُ الرأس رُفعت ومعها عدّادُها، فلو دخل البندُ بلا
# عدّادٍ لم يبقَ في الشاشة موضعٌ يقول «عندك رسالة» — ولا يُرى النقصُ إلّا
# حين تصل رسالةٌ ولا يعلم بها أحد.
run "(د) بندٌ بلا عدّاد" \
  sub "$P" \
"            unread: _unread," \
"            unread: 0,"

# ── هـ) ولا تُرسم الحبّةُ أصلاً ────────────────────────────────────────────
run "(هـ) الحبّةُ لا تُرسم" \
  sub "$K" \
"              if (item.unread > 0)" \
"              if (false && item.unread > 0) // ignore: dead_code"

# ── و) وتزيح الحبّةُ أيقونةَ بندها ─────────────────────────────────────────
#
# صفٌّ بدل الكومة: البندُ الذي عليه حبّةٌ ينحرف عن إخوته.
run "(و) الحبّةُ تزيح الأيقونة" \
  sub "$K" \
"          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: GlassNavBar.iconSize, color: AppColors.ink2)," \
"          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: GlassNavBar.iconSize, color: AppColors.ink2),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
