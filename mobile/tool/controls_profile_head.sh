#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرأس «الملف الشخصي»: الارتفاعُ والفراغُ ولونُ الأيقونتين.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وثلاثتُها اختياراتُ صاحب المنصّة لا اجتهادُ أحد** — اختار الارتفاعَ من
# أربع لقطات، وقال «ما يكون فراغ بين بياناتي والغلاف»، وقال «خلّي لي رقم
# الجوال والبريد نفس لون الاسم الكامل والمحافظة». فما يحرسه هذا السكربتُ
# أنّ اختيارَه لا يُنقض صمتاً.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

# **وحزمتان لا واحدة.** قياسُ الرأس في `profile_head`، وما حوله في
# `edit_profile` — وكسرُ الارتفاع يُنزل سطرَ البريد تحت حافّة النافذة،
# فتسقط الثانيةُ أيضاً. ويُشغَّلان معاً لئلّا يُظنّ السقوطُ في غير موضعه.
SUITE="test/profile_head_test.dart test/edit_profile_test.dart"

E=lib/src/screens/edit_profile.dart

FILES=("$E")
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

# ── أ) يعود الغلافُ قصيراً ──────────────────────────────────────────────────
#
# ١٠٦ هو المشحونُ قبل اختياره. ولا يسقط هذا بسؤال «أيوجد غلاف؟» — موجودٌ
# في الحالين. يسقط لأنّ الارتفاعَ المرسومَ يُقاس.
run "(أ) يعود الغلافُ ١٠٦" \
  sub "$E" \
"const double _coverHeight = 230;" \
"const double _coverHeight = 106;"

# ── ب) ويعود الفراغُ تحت الغلاف ─────────────────────────────────────────────
#
# **وهو نصُّ ما طلب إزالته.** والفراغُ لا يُرى في شجرةٍ تُسأل «أفيها بطاقة؟»
# — فيُقاس بُعدُ رأس البطاقة عن قاع القرص.
run "(ب) يعود الفراغُ بينهما" \
  sub "$E" \
"                _ProfileArt(profile: _profile!),
                AppCard(" \
"                _ProfileArt(profile: _profile!),
                const SizedBox(height: Space.xl),
                AppCard("

# ── ج) ويقصُر الحدُّ فيُقصّ القرص ───────────────────────────────────────────
#
# عطبٌ لا يُرى إلّا بالعين: الحدُّ لا يسع نزولَ القرص، فيُقطع نصفُه.
run "(ج) الحدُّ لا يسع القرص" \
  sub "$E" \
"      height: _coverHeight + _discSize / 2 + 6," \
"      height: _coverHeight,"

# ── د) ويعود لونُ الأيقونتين `muted` ────────────────────────────────────────
#
# **وهو الفرقُ الذي أخرجه.** ولا يسقط بسؤال «أموجودةٌ الأيقونة؟» — موجودةٌ
# في الحالين. يسقط لأنّها تُقارَن بأيقونة الحقل الحقيقيّة في الشاشة نفسها.
run '(د) يعود اللونُ muted' \
  sub "$E" \
"              Icon(icon, size: 20, color: iconColor)," \
"              Icon(icon, size: 20, color: AppColors.muted),"

# ── هـ) ولونٌ من الثيمة لكنّه ليس لونَ الحقول ───────────────────────────────
#
# **وهذا يفرّق بين «لونٍ معقول» و«لونِ الحقول».** لو اكتفى الشرطُ بأنّ
# اللونَ من الثيمة لَمرّ هذا الكسرُ — واللونان مختلفان في الشاشة.
run "(هـ) لونٌ آخرُ من الثيمة" \
  sub "$E" \
"        theme.inputDecorationTheme.prefixIconColor ?? theme.colorScheme.onSurfaceVariant;" \
"        theme.inputDecorationTheme.prefixIconColor ?? theme.colorScheme.onSurface;"

# ── و) ويعود القياسُ ١٩ ─────────────────────────────────────────────────────
#
# اللونُ وحده لا يكفي: أيقونتان بلونٍ واحدٍ وقياسين تُقرآن مختلفتين.
run "(و) يعود القياسُ ١٩" \
  sub "$E" \
"              Icon(icon, size: 20, color: iconColor)," \
"              Icon(icon, size: 19, color: iconColor),"

# ── ز) ويخرج السطران من البطاقة ─────────────────────────────────────────────
#
# **وأرضيّتُهما تفترق عنها فورَ خروجهما.** ولا يسقط هذا بسؤال «أموجودٌ سطرُ
# الجوال؟» — موجودٌ في الحالين. يسقط لأنّ حدَّه يُقاس داخل حدّ البطاقة.
run "(ز) السطران خارج البطاقة" \
  sub "$E" \
"                    const SizedBox(height: Space.lg),
                    const Divider(height: 1, color: AppColors.hairline),
                    const SizedBox(height: Space.md)," \
"                  ],
                ),
                const SizedBox(height: Space.md),
                AppCard(
                  children: ["

# ── ح) ويعود إليهما الشريطُ الورديّ ─────────────────────────────────────────
#
# **وهو الفرقُ الذي شُكي منه بعينه.** حبرٌ واحدٌ يُقرأ بلونين لاختلاف ما
# تحته — فيُقاس أنّ اللونَ لم يعُد يُرسم في الشاشة.
run "(ح) يعود الشريطُ الورديّ" \
  sub "$E" \
"    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)," \
"    return Container(
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
