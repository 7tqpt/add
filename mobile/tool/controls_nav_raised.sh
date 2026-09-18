#!/usr/bin/env bash
# ضوابطُ سالبةٌ للقرص المرتفع في شريط التنقّل، ولشريط المزوّد الزجاجيّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/nav_raised_test.dart test/provider_shell_nav_test.dart test/shell_test.dart"

K=lib/src/ui/kit.dart
P=lib/src/screens/provider_shell.dart

FILES=("$K" "$P")
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

echo; echo "== ضوابطُ القرص =="

# ── أ) ينزل القرصُ إلى داخل الشريط فلا يرتفع ───────────────────────────────
#
# وهو الطلبُ بعينه: قرصٌ موجودٌ لا يعلو شيئاً.
run "(أ) القرصُ لا يرتفع" \
  sub "$K" \
"                                child: _GlassNavDisc(" \
"                                child: const SizedBox.shrink(), // ignore: dead_code
                                dummy: _GlassNavDisc("

# ── ب) ولا يُضغط القرصُ ────────────────────────────────────────────────────
#
# المختارُ أكبرُ هدفٍ في الشريط، وضغطةٌ لا تقع عليه تُرى عطلاً.
run "(ب) القرصُ لا يستجيب" \
  sub "$K" \
"        child: GestureDetector(
          onTap: onTap," \
"        child: GestureDetector(
          onTap: null,"

# ── ج) وتذهب كلماتُ الجيران ────────────────────────────────────────────────
#
# من لا يعرف الأيقونةَ يقرأ اسمَها — وهو ما لم يُطلب رفعُه.
run "(ج) كلماتُ الجيران تذهب" \
  sub "$K" \
"          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5," \
"          Text(
            '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,"

# ── د) ولا تزيد المسافةُ بمقدار القرص ──────────────────────────────────────
#
# **وهذا أخطرُها لأنّه لا يُرى إلّا في آخر قائمة**: كلُّ شاشةٍ تبدو سليمةً،
# ثمّ يبلغ صاحبُها آخرَ سطرٍ فيجده تحت القرص.
run "(د) المسافةُ لا تزيد" \
  sub "$K" \
"const double glassNavSpace = 96 + GlassNavBar.raise;" \
"const double glassNavSpace = 60;"

echo; echo "== ضوابطُ شريط المزوّد =="

# ── هـ) ويعود شريطُ المزوّد مادّيّاً ───────────────────────────────────────
run "(هـ) عودةُ الشريط المادّيّ" \
  sub "$P" \
"      bottomNavigationBar: GlassNavBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i)," \
"      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'تقويمي'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'خدماتي'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'ملفي'),
        ],
      ),
      // ignore: dead_code
      persistentFooterButtons: const [],
      drawer: GlassNavBar(
        index: 0,
        onSelect: (_) {},"

# ── و) ولا يمرّ المحتوى تحت الزجاج ─────────────────────────────────────────
#
# فيقف الشريطُ على بياضٍ ولا يجد التمويهُ ما يموّهه — زجاجٌ بالاسم لا بالعين.
run "(و) المحتوى لا يمرّ تحته" \
  sub "$P" \
"      extendBody: true," \
"      extendBody: false,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
