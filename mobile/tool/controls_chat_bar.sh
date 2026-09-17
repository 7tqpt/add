#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشريط المحادثة العلويّ.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُها (ج): يُفتح البابُ لمقدّم الخدمة أيضاً.** وهو كسرٌ يبدو إحساناً
# — شريطٌ يُضغط للطرفين — وهو في الحقيقة وعدٌ بوجهةٍ لا توجد: **لا ملفَّ عامّ
# للعميل في التطبيق أصلاً**. فيضغط مقدّمُ الخدمة فلا يقع شيء.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/chat_bar_test.dart test/chat_test.dart"

C=lib/src/screens/chat.dart

FILES=("$C")
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

echo; echo "== الضوابط =="

# ── أ) يذهب القرصُ من الشريط ────────────────────────────────────────────────
run "(أ) لا قرصَ في الشريط" \
  sub "$C" \
"        _OtherAvatar(name: widget.otherName, path: _avatar)," \
"        const SizedBox.shrink(),"

# ── ب) ولا يُضغط الشريطُ أصلاً ──────────────────────────────────────────────
#
# **ولا يسقط هذا بسؤال «أموجودٌ القرص؟»** — موجودٌ في الحالين. يسقط لأنّ
# الشجرةَ تُسأل **بعد الضغط**: أفُتح ملفُّ القاعة؟
run "(ب) الشريطُ لا يُضغط" \
  sub "$C" \
"    if (widget.mySide != ChatSide.customer || id == null || id.isEmpty) {
      return null;
    }" \
"    if (true) {
      return null;
    }"

# ── ج) ويُفتح البابُ لمقدّم الخدمة أيضاً ────────────────────────────────────
#
# **وهو كسرٌ يبدو إحساناً.** شريطٌ يُضغط للطرفين — ووجهتُه عند مقدّم الخدمة
# ملفٌّ لا وجودَ له. وهذا اختيارُ صاحب المنصّة من اثنين عُرضا عليه.
run "(ج) يُضغط عند مقدّم الخدمة" \
  sub "$C" \
"    if (widget.mySide != ChatSide.customer || id == null || id.isEmpty) {" \
"    if (id == null || id.isEmpty) {"

# ── د) وتُفتح الضغطةُ على مزوّدٍ مجهول ──────────────────────────────────────
#
# محادثةٌ حُذف مزوّدُها تبقى للعميل — وضغطةٌ تفتح ملفَّ `null` تُسقط الشاشة.
run "(د) ضغطةٌ بلا مزوّد" \
  sub "$C" \
"    final id = _providerId;
    if (widget.mySide != ChatSide.customer || id == null || id.isEmpty) {" \
"    final id = _providerId ?? '';
    if (widget.mySide != ChatSide.customer) {"

# ── هـ) ويذهب حرفُ الاسم فيبقى قرصٌ أصمّ ────────────────────────────────────
#
# أكثرُ الناس بلا صورة، فالحرفُ هو ما يُرى غالباً لا الصورة.
run "(هـ) قرصٌ بلا حرف" \
  sub "$C" \
"    final letter = trimmed.isEmpty ? tr('؟') : trimmed.characters.first;" \
"    final letter = '';"

# ── و) ويُرسم السهمُ حيث لا ضغطة ────────────────────────────────────────────
#
# **وهو وعدٌ كاذبٌ بالعين.** سهمٌ يقول «هنا وجهة» فوق شريطٍ لا يُضغط.
run "(و) سهمٌ بلا ضغطة" \
  sub "$C" \
"        if (open != null) const Icon(Icons.chevron_left, size: 22, color: AppColors.muted)," \
"        const Icon(Icons.chevron_left, size: 22, color: AppColors.muted),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
