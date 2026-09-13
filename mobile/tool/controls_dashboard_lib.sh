#!/usr/bin/env bash
# ضوابطُ سالبةٌ لأوّل حزمةِ اختباراتٍ للوحة التحكّم.
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** واللوحةُ كانت بلا اختبارٍ واحد، فأوّلُ
# ما يجب أن يُقاس ليس ما تقوله الحزمةُ عن نفسها بل **أنّها تحمرّ حين تُكسر
# الشيفرة**. وحزمةٌ خضراءُ فوق شيفرةٍ مكسورةٍ أسوأُ من لا حزمة: تُعطي إذناً
# بالدمج باسمِ حرزٍ لا يحرس.
#
# **وموضعُه هنا مع إخوته وإن كان يحرس `src/`** — الضوابطُ في موضعٍ واحدٍ
# يُقرأ، لا في ثلاثةِ مواضعَ يُنسى أحدُها.
set -uo pipefail
cd "$(dirname "$0")/../.."
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

F=src/lib/format.ts
C=src/lib/csv.ts
P=src/lib/permissions.ts

BACKUP=$(mktemp -d)
for f in "$F" "$C" "$P"; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in "$F" "$C" "$P"; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
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
  if npx vitest run >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if npx vitest run >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ــــ التنسيق ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ

# أ) **المثنّى يسقط فتُكتب «٢ يوم»** — نصٌّ مكسورٌ في شاشةٍ عربيّة.
run "أ) لا مثنّى" sub "$F" \
  "  if (n === 2) return forms.two" \
  ""

# ب) **وجمعُ القلّة يسقط** — «٣ يوماً» مكان «٣ أيام».
run "ب) لا جمعَ قلّة" sub "$F" \
  "  if (n >= 3 && n <= 10) return \`\${int.format(n)} \${forms.few}\`" \
  ""

# ج) **والسالبُ يُطابَق بإشارته** — فيسقط كلُّ عددٍ سالبٍ في فرع «ما فوق
#    العشرة»، ويُكتب «‎-2 يوماً».
run "ج) السالبُ بإشارته" sub "$F" \
  "  const n = Math.abs(count)" \
  "  const n = count"

# د) **والمستقبلُ يُصاغ بـ«منذ»** — وهو عيبٌ وقع فعلاً: دعوةٌ تنتهي بعد
#    أسبوعٍ كانت تُقرأ «الآن» لأنّ الفرقَ سالبٌ فيقع تحت الدقيقة.
run "د) المستقبلُ «منذ»" sub "$F" \
  "  if (diffMs < -60_000) return formatUntil(-diffMs)" \
  ""

# هـ) **والساعةُ التامّةُ تُتبع بصفر دقائق** — «4 س 0 د».
run "هـ) ساعةٌ وصفرُ دقائق" sub "$F" \
  "  if (hours > 0) return minutes === 0 ? \`\${int.format(hours)} س\` : \`\${int.format(hours)} س \${int.format(minutes)} د\`" \
  "  if (hours > 0) return \`\${int.format(hours)} س \${int.format(minutes)} د\`"

# و) **ومنتصفُ الليل يُكتب «0:30 ص»** — والساعةُ صفرٌ لا تُقال في العربيّة
#    ولا في الإنجليزيّة.
run "و) صفرٌ صباحاً" sub "$F" \
  "  const hour = h % 12 === 0 ? 12 : h % 12" \
  "  const hour = h % 12"

# ز) **وما لا يُقرأ يُخمَّن** — «صباحاً» تخرج «NaN:00 ص».
run "ز) وقتٌ لا يُقرأ يُخمَّن" sub "$F" \
  "  if (Number.isNaN(h)) return value" \
  ""

# ــــ التصدير ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ

# ح) **وعلامةُ ترتيب البايتات تسقط** — فتصل العناوينُ العربيّةُ وأسماءُ
#    الناس حروفاً مشوّهةً في Excel. **ولا يظهر هذا إلّا عند من يفتح الملفّ.**
run "ح) لا BOM" sub "$C" \
  "  return '﻿' + lines.join('\r\n')" \
  "  return lines.join('\r\n')"

# ط) **والخانةُ لا تُحاط** — ففاصلةٌ في اسمٍ لاتينيٍّ تشطر العمود وينزاح
#    الجدولُ كلُّه.
run "ط) لا إحاطةَ للخانة" sub "$C" \
  "  return /[\",\n\r]/.test(text) ? \`\"\${text.replace(/\"/g, '\"\"')}\"\` : text" \
  "  return text"

# ي) **وعلامةُ التنصيص لا تُضاعَف** — فاسمٌ فيه اقتباسٌ يقطع الخانة.
run "ي) لا مضاعفةَ للتنصيص" sub "$C" \
  "text.replace(/\"/g, '\"\"')" \
  "text"

# ك) **والفارغُ يُكتب «null»** — في كلّ خانةٍ لا قيمةَ لها في التقرير.
run "ك) الفارغُ يُكتب null" sub "$C" \
  "  const text = value === null || value === undefined ? '' : String(value)" \
  "  const text = String(value)"

# ــــ الصلاحيات ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ

# ل) **ومن لا دورَ له يُقرأ مسموحاً** — وهي حالُ من لم تصل جلستُه بعد، أو
#    من نُزع دورُه وهو مفتوحُ اللوحة. **والافتراضُ منعٌ لا سماح.**
run "ل) من لا دورَ له يُسمح له" sub "$P" \
  "  if (!role) return 'none'" \
  "  if (!role) return 'write'"

# م) **ودورٌ لا نعرفه يُقرأ سماحاً** — لوحةٌ قديمةٌ أمام قاعدةٍ أحدثَ تفتح
#    ما لا تعرف بدل أن تُخفيه.
run "م) دورٌ مجهولٌ يُسمح له" sub "$P" \
  "  return ROLE_AREAS[role]?.[area] ?? 'none'" \
  "  return ROLE_AREAS[role]?.[area] ?? 'write'"

# ن) **و«قراءة» تُقرأ تعديلاً** — فيُعرض زرُّ التعديل لمن لا يملكه، يضغطه
#    فيرتدّ عليه الطلبُ بخطأٍ لا يفهمه.
run "ن) القراءةُ تعديل" sub "$P" \
  "  return levelOf(role, area) === 'write'" \
  "  return levelOf(role, area) !== 'none'"

# س) **ويُدير المسؤولين غيرُ المالك** — وهو نصُّ العهد المكتوب في وصف الدور.
run "س) المدير يُدير المسؤولين" sub "$P" \
  "    trust: 'write', support: 'write', ops: 'write', settings: 'write', admins: 'none',
  }," \
  "    trust: 'write', support: 'write', ops: 'write', settings: 'write', admins: 'write',
  },"

# ع) **ويرى المطّلعُ المال** — «والمال محجوب عنه» في وصفه.
run "ع) المطّلعُ يرى المال" sub "$P" \
  "    bookings: 'read', directory: 'read', catalog: 'read', finance: 'none',
    trust: 'read', support: 'read', ops: 'read', settings: 'read', admins: 'none'," \
  "    bookings: 'read', directory: 'read', catalog: 'read', finance: 'read',
    trust: 'read', support: 'read', ops: 'read', settings: 'read', admins: 'none',"

# ف) **ويسقط مجالٌ من قائمة العرض** — فيختفي من شاشة الصلاحيّات كلِّها وهو
#    قائمٌ في القاعدة، ولا رسالةَ خطأٍ تقول ذلك.
run "ف) مجالٌ يسقط من القائمة" sub "$P" \
  "  'admins',
]" \
  "]"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
