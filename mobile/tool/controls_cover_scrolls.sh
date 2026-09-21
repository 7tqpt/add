#!/usr/bin/env bash
# ضوابطُ سالبةٌ لغلافِ صفحة الخدمة: يمشي مع المحتوى ويخرج بالتمرير.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/cover_scrolls_test.dart"
D=lib/src/screens/service_detail.dart

BACKUP=$(mktemp -d)
cp "$D" "$BACKUP/d"
restore() { cp "$BACKUP/d" "$D"; }
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

echo; echo "== العطبُ الأصليُّ يعود =="

# ── أ) يعود العمودُ: الغلافُ خارجَ الممرَّر ───────────────────────────────
#
# **وهو ما شكا منه بعينه**: «ليش صورة ثابتة؟». والقائمةُ تعمل، والغلافُ
# يُرى، ولا شيءَ يحمرّ — إلّا أنّه لا يتزحزح.
back_to_column() {
  python3 - <<'PY'
import io
p = 'lib/src/screens/service_detail.dart'
s = io.open(p, encoding='utf-8').read()
old_open = """      body: ListView(
        padding: EdgeInsets.zero,
        children: ["""
new_open = """      body: Column(
        children: ["""
old_close = """          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: _body(context),
          ),"""
new_close = """          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: _body(context),
          )),"""
assert s.count(old_open) == 1 and s.count(old_close) == 1
s = s.replace(old_open, new_open, 1).replace(old_close, new_close, 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}
run "(أ) يعود الغلافُ خارجَ الممرَّر" back_to_column

echo; echo "== موضعُ الطيران =="

# ── ب) ويدخل الغلافُ في `FutureBuilder` ───────────────────────────────────
#
# **وهذا يكسر بصمت:** الشاشةُ تعمل وتُمرَّر ويخرج الغلاف — ولا يظهر النقصُ
# إلّا في **لحظة الانتقال**: يطير الغلافُ من البطاقة إلى فراغٍ ويرتدّ.
hide_while_loading() {
  sub "$D" \
"          if (widget.coverPath != null)
            Hero(" \
"          if (widget.coverPath != null && _loaded)
            Hero("
  python3 - <<'PY'
import io
p = 'lib/src/screens/service_detail.dart'
s = io.open(p, encoding='utf-8').read()
anchor = "  static const _blockHeight = 260.0;"
assert s.count(anchor) == 1
s = s.replace(anchor, anchor + "\n\n  bool _loaded = false;", 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}
run "(ب) لا غلافَ أثناء التحميل" hide_while_loading

echo; echo "== الترتيب =="

# ── ج) ويقع الغلافُ تحت المحتوى ───────────────────────────────────────────
#
# يُمرَّر ويخرج كما طُلب، لكنّ من فتح الخدمة لا يراه أوّلاً — وهو أوّلُ ما
# جاء يراه.
below_content() {
  python3 - <<'PY'
import io
p = 'lib/src/screens/service_detail.dart'
s = io.open(p, encoding='utf-8').read()
body = """          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: _body(context),
          ),
        ],
      ),"""
assert s.count(body) == 1
# يُنقل المحتوى فوق الغلاف: يُحقن قبلَ `if (widget.coverPath`
head = "          // **والغلافُ خارجَ `FutureBuilder` عمداً.**"
assert s.count(head) == 1
s = s.replace(body, """        ],
      ),""", 1)
s = s.replace(head, """          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: _body(context),
          ),
""" + head, 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
}
run "(ج) الغلافُ تحت المحتوى" below_content

echo; echo "== ممرٌّ واحد =="

# ── د) وتعود قائمةٌ داخلَ قائمة ───────────────────────────────────────────
#
# قائمتان تتنازعان الإصبع: يُمرَّر الداخليُّ فيقف الخارجيُّ، فيبقى الغلافُ
# ثابتاً وهو **داخلَ** ممرٍّ — فلا يكفي أن يُسأل «أداخلَ القائمة هو؟».
inner_list() {
  # **وكسرٌ بمرساةٍ واحدة.** كان الكسرُ بمرساتين، فأخطأت الثانيةُ وطابقت
  # مرّتين — فلم تُطبَّق، وسقطت الحزمةُ على **عطبِ ترجمةٍ** لا على الضمانة.
  # وضابطٌ يسقط لغير سببه ضابطٌ كاذبٌ وإن بدا أخضر.
  sub "$D" \
"            child: _body(context)," \
"            child: SizedBox(
              height: 900,
              child: ListView(children: [_body(context)]),
            ),"
}
run "(د) قائمةٌ داخلَ قائمة" inner_list

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
