#!/usr/bin/env bash
# ضوابطُ سالبةٌ للحضور — «متّصل الآن» و«آخر ظهور».
#
# كلُّ ضابطٍ يكسر ضمانةً واحدةً في الشيفرة الحيّة ثمّ يشغّل الحزمة: إن بقيت
# خضراءَ فالحارسُ لا يحرس. والملفّاتُ تُعاد كما كانت في كلّ حال.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/presence_test.dart

FILES=(
  lib/src/core/presence.dart
  lib/src/ui/kit.dart
  lib/src/screens/chat.dart
  lib/src/screens/provider_public.dart
  lib/src/screens/customer_shell.dart
)

BACKUP=$(mktemp -d)
for f in "${FILES[@]}"; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in "${FILES[@]}"; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
trap 'restore; rm -rf "$BACKUP"' EXIT

PASS=0; FAIL=0

# يستبدل مرّةً واحدة، ويرفض المرساةَ التي تطابق غيرَ مرّة: مرساةٌ تطابق
# موضعين تكسر ما لم يُقصد، ومرساةٌ لا تطابق شيئاً لا تكسر شيئاً — وكلاهما
# يُخرج ضابطاً كاذباً.
sub() {
  local file="$1" old="$2" new="$3" n
  n=$(python3 - "$file" "$old" <<'PY'
import sys
print(open(sys.argv[1], encoding='utf-8').read().count(sys.argv[2]))
PY
)
  if [ "$n" != "1" ]; then
    echo "   ✗ المرساةُ تطابق $n مرّة — لا كسرَ وقع"; return 1
  fi
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

P=lib/src/core/presence.dart
K=lib/src/ui/kit.dart
C=lib/src/screens/chat.dart
V=lib/src/screens/provider_public.dart
S=lib/src/screens/customer_shell.dart

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
  echo "أخضر."
else
  echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1
fi

echo
echo "== الضوابط =="

# أ) المهلةُ تساوي النبضةَ لا ضِعفَها — فنبضةٌ ساقطةٌ تُخرج مستخدماً لم يخرج.
run "أ) المهلةُ بقدر النبضة" sub "$P" \
  '  static const window = Duration(minutes: 2);' \
  '  static const window = Duration(minutes: 1);'

# ب) ساعةُ الخادم تسبق ساعةَ الجهاز فيُقرأ الفرقُ سالباً — ومن نبض قبل ثانيةٍ
#    يُعدّ غائباً.
run "ب) الظهورُ في المستقبل يُعدّ غياباً" sub "$P" \
  '    return since < window;' \
  '    return !since.isNegative && since < window;'

# ج) سطرٌ لمن لا ظهورَ له — يشغل مكاناً ولا يحمل خبراً.
run "ج) «آخر ظهور غير معروف» لمن لا ظهورَ له" sub "$K" \
  '    if (seen == null) return const SizedBox.shrink();' \
  "    if (seen == null) return const Text('آخر ظهور غير معروف');"

# د) «غير متّصل» — حكمٌ على ما سيجري لا خبرٌ عمّا جرى.
run "د) «غير متّصل» بدل آخرِ الظهور" sub "$K" \
  "      'آخر ظهور \${formatRelative(seen.toIso8601String())}'," \
  "      'غير متّصل',"

# هـ) النقطةُ وحدَها بلا نصّ — ومن لا يميّز الأخضرَ لا يقرأ شيئاً.
run "هـ) نقطةٌ خضراءُ بلا نصّ" sub "$K" \
  "          Text(
            'متّصل الآن'," \
  "          Text(
            ''," \

# و) النقطةُ بلون الحبر الباهت — فلا تُقرأ حالةً.
run "و) نقطةٌ بلا لونِ حالة" sub "$K" \
  'decoration: const BoxDecoration(color: AppColors.good, shape: BoxShape.circle),' \
  'decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),'

# ز) أخضرُ فاتحٌ يبدو أجملَ على الشاشة ولا يُقرأ في الشمس.
run "ز) أخضرُ فاتحٌ تحت العتبة" sub "$K" \
  '            style: TextStyle(
              fontSize: size,
              color: AppColors.good,' \
  '            style: TextStyle(
              fontSize: size,
              color: const Color(0xFF4ADE80),'

# ح) النبضةُ لا تبدأ من القشرة — **وهذه هي العلّةُ الأصليّةُ بعينها**: عمودٌ
#    في القاعدة لا يكتبه أحد.
run "ح) القشرةُ لا تبدأ النبضة" sub "$S" \
  '    Presence.start();' \
  '    // Presence.start();'

# ط) مؤقّتُ السؤال عن الحضور يبقى بعد زوال الشاشة.
run "ط) مؤقّتٌ يبقى بعد زوال الدردشة" sub "$C" \
  '    _seenTick?.cancel();' \
  '    // _seenTick?.cancel();'

# ي) الشريطُ يعود اسماً بلا حضور.
run "ي) الدردشةُ بلا سطرِ حضور" sub "$C" \
  '            PresenceLine(lastSeen: _seen, size: 11.5),' \
  '            const SizedBox.shrink(),'

# ك) الملفُّ العامُّ لا يُمرَّر إليه الحضور — يُجلب ولا يُعرض.
run "ك) الملفُّ العامُّ لا يعرض ما جلبه" sub "$V" \
  '                      _Head(provider: p, lastSeen: _seen),' \
  '                      _Head(provider: p),'

echo
echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
