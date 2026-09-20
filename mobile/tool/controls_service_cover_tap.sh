#!/usr/bin/env bash
# ضوابطُ سالبةٌ لغلاف صفحة الخدمة: يُفتح بالضغط ويُقلَّب فيه.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/service_cover_tap_test.dart"

D=lib/src/screens/service_detail.dart
P=lib/src/ui/photo_view.dart

FILES=("$D" "$P")
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

echo; echo "== الضغط =="

# ── أ) يعود الغلافُ الواحدُ ساكناً ────────────────────────────────────────
#
# **وهو الحالُ الذي شُكي منه بعينه.**
run "(أ) الغلافُ الواحدُ ساكن" \
  sub "$D" \
"                        onTap: () => openGallery(
                          context,
                          urls: [Api.mediaUrl(widget.coverPath) ?? ''],
                        )," \
"                        onTap: null,"

# ── ب) ويعود المعرضُ المقلَّبُ ساكناً ─────────────────────────────────────
run "(ب) المعرضُ ساكن" \
  sub "$D" \
"                  onTap: () => widget.onOpen(i)," \
"                  onTap: null,"

echo; echo "== أيّ صورةٍ تُفتح =="

# ── ج) ويُفتح على أوّل الصور أبداً ────────────────────────────────────────
#
# **وهذه تنكسر بصمت**: العارضُ يُفتح ويعمل ويبدو سليماً، ولا يُرى نقصُه
# إلّا لمن قلّب قبل أن يضغط.
run "(ج) يُفتح على الأولى أبداً" \
  sub "$D" \
"                        initialIndex: i,
                      ),
                    );
                  }," \
"                        initialIndex: 0,
                      ),
                    );
                  },"

# ── د) ويُهمَل الفهرسُ في العارض نفسِه ────────────────────────────────────
run "(د) العارضُ يتجاهل الفهرس" \
  sub "$P" \
"  late int _index = widget.initialIndex.clamp(0, widget.urls.length - 1);" \
"  late int _index = 0;"

echo; echo "== التقليبُ والعدّاد =="

# ── هـ) ولا يُقلَّب داخلَ العارض ──────────────────────────────────────────
#
# وهو الفرقُ بين (ج) و(أ): يُرجَع ليُقلَّب ويُضغط من جديد.
run "(هـ) لا تقليبَ داخلَ العارض" \
  sub "$P" \
"      body: PageView.builder(
        key: const ValueKey('photo-gallery-pages')," \
"      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        key: const ValueKey('photo-gallery-pages'),"

# ── و) ويذهب العدّاد ──────────────────────────────────────────────────────
#
# بلا رقمٍ لا يدري أبقيت صورةٌ أم انتهت، فيقلّب في فراغٍ ليتأكّد.
run "(و) لا عدّادَ يقول أين هو" \
  sub "$P" \
"        title: widget.urls.length < 2
            ? null
            : Text(" \
"        title: widget.urls.length < 99
            ? null
            : Text("

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
