#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرسم الصورة في قائمة المحادثات.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وحدُّ الدالّة في القاعدة له ضوابطُه**
# (`supabase/tests/controls_conversation_avatars.sh`). وهذه لما فوقه: أنّ
# المسارَ يصل القرصَ ولا يُبتلع في الطريق، وأنّ الحرفَ يبقى لمن لا صورةَ له.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/conversations_avatar_test.dart test/white_app_test.dart"

C=lib/src/screens/conversations.dart
M=lib/src/data/models.dart

FILES=("$C" "$M")
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

# ── أ) يذهب القرصُ من الصفّ ─────────────────────────────────────────────────
run "(أ) لا قرصَ في الصفّ" \
  sub "$C" \
"      leading: _Avatar(name: c.otherName, path: c.otherAvatar)," \
"      leading: const SizedBox.shrink(),"

# ── ب) ويُبتلع المسارُ في الطريق إلى القرص ──────────────────────────────────
#
# **وهذا أخطرُها لأنّه لا يُرى عطباً**: القرصُ موجودٌ، والحرفُ فيه، وكلُّ
# شيءٍ يبدو سليماً — والصورةُ لا تصل أبداً. وهو الحالُ الذي شُكي منه بعينه.
#
# **ولم يسقط أوّلَ مرّة، والعلّةُ في القياس لا فيه:** لا سلّةَ في
# `flutter test` فتعود `avatarUrl` فارغةً أبداً، فكلُّ قرصٍ يرسم حرفاً سواءٌ
# وصل المسارُ أو مُحي. فرُكّب `Api.avatarUrlOverride` وأُصلح القياس.
run "(ب) المسارُ لا يصل القرص" \
  sub "$C" \
"      leading: _Avatar(name: c.otherName, path: c.otherAvatar)," \
"      leading: _Avatar(name: c.otherName, path: ''),"

# ── ج) ويذهب الحرفُ فيبقى قرصٌ أصمّ ─────────────────────────────────────────
#
# أكثرُ الحسابات بلا صورة، فالحرفُ هو ما يُرى غالباً لا الصورة.
#
# **وهذا الضابطُ لم يسقط أوّلَ مرّة، والعلّةُ في القياس لا فيه:** كان الشرطُ
# يسأل «أفي القرص نصّ؟» — و`Text('')` نصٌّ موجودٌ وقرصٌ أصمّ. فصار يُقرأ
# الحرفُ نفسُه.
run "(ج) قرصٌ بلا حرف" \
  sub "$C" \
"      trimmed.isEmpty ? tr('؟') : trimmed.characters.first," \
"      ''," 

# ── د) ويُقرأ عمودٌ غيرُ الذي يرسله الخادم ──────────────────────────────────
#
# **ولا يسقط هذا في الجهاز إلّا بالعين**: النموذجُ يقرأ فارغاً أبداً، فترسم
# القائمةُ حروفاً وهي تظنّ أنّها ترسم صوراً.
run "(د) اسمُ عمودٍ خاطئ" \
  sub "$M" \
"    otherAvatar: (m['other_avatar'] ?? '') as String," \
"    otherAvatar: (m['avatar'] ?? '') as String,"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
