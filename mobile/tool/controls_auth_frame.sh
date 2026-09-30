#!/usr/bin/env bash
# ضوابطُ سالبةٌ لشاشات الباب على تصميم صاحب المنصّة — الدخولُ والإنشاءُ
# والاستعادةُ والقفل.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**
# ليُرى أنّه سقط للسبب المقصود: ضابطٌ يُسقط كلَّ شيءٍ كاذبٌ كالذي لا يُسقط
# شيئاً.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`
# ثمّ يعيدها.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/auth_frame_test.dart test/auth_layout_test.dart test/brand_mark_test.dart test/biometric_test.dart test/lock_screen_test.dart test/recover_test.dart test/polish_test.dart"
FRAME=lib/src/ui/auth_frame.dart
AUTH=lib/src/screens/auth.dart
LOCK=lib/src/screens/lock.dart

BACKUP=$(mktemp -d)
cp "$FRAME" "$BACKUP/frame"; cp "$AUTH" "$BACKUP/auth"; cp "$LOCK" "$BACKUP/lock"
restore() { cp "$BACKUP/frame" "$FRAME"; cp "$BACKUP/auth" "$AUTH"; cp "$BACKUP/lock" "$LOCK"; }
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
  local out
  out=$(timeout 900 flutter test -r expanded $SUITE 2>&1)
  if echo "$out" | grep -q "All tests passed"; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط:"
    echo "$out" | grep -E "\[E\]$" | sed -E 's/^.*test\/([^:]+): /     • \1: /' | sort -u | head -8
    PASS=$((PASS+1))
  fi
  restore
}

# ── الإطار ──────────────────────────────────────────────────────────────────
run "(أ) رأسٌ مصمتٌ بلا تدرّج" sub "$FRAME" \
  "colors: [AppColors.accentDeep, AppColors.accent]," \
  "colors: [AppColors.accent, AppColors.accent],"

run "(ب) البطاقةُ تنزل عن الرأس" sub "$FRAME" \
  "top: head - 4," "top: head + 40,"

run "(ج) البطاقةُ من الحافّة إلى الحافّة" sub "$FRAME" \
  "padding: const EdgeInsets.fromLTRB(20, 0, 20, 24)," \
  "padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),"

roses_over_card() {
  python3 - "$FRAME" <<'PY2'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = s.index("          // ── الوردُ في الزاويتين")
b = s.index("          // ── البطاقة ──")
roses = s[a:b]
s = s[:a] + s[b:]
end = "        ],\n      ),\n    );\n  }\n}\n\n/// القلبُ و«فرحتي»"
if s.count(end) != 1:
    sys.exit(1)
s = s.replace(end, roses + end)
open(p, 'w', encoding='utf-8').write(s)
PY2
}
run "(د) الوردُ فوق البطاقة" roses_over_card

run "(هـ) الوردُ من أصلٍ آخر" sub "$FRAME" \
  "            WelcomeRoses.asset,
            key: ValueKey(left ? 'rose-left' : 'rose-right')," \
  "            'assets/brand/app_mark.png',
            key: ValueKey(left ? 'rose-left' : 'rose-right'),"

run "(و) الزرُّ الأوّلُ بلا تدرّج" sub "$FRAME" \
  "for (final c in const [AppColors.accentLift, AppColors.accent, AppColors.accentDeep])" \
  "for (final c in const [AppColors.accent, AppColors.accent, AppColors.accent])"

run "(ز) العينُ لا تفعل شيئاً" sub "$FRAME" \
  "onPressed: () => setState(() => _hidden = !_hidden)," "onPressed: () {},"

run "(ح) النجومُ على العنوان" sub "$FRAME" \
  "top: title == null ? 0 : top + 48," "top: 0,"

run "(ط) العنوانُ كلُّه نبيذيّ" sub "$FRAME" \
  "style: const TextStyle(color: AppColors.ink)," "style: const TextStyle(),"

# ── الدخول ──────────────────────────────────────────────────────────────────
flexible_back() {
  sub "$AUTH" "            Expanded(
              child: Align(" "            Flexible(
              child: Align(" &&
  sub "$AUTH" "            Text(tr('تذكّرني')" "            const Spacer(),
            Text(tr('تذكّرني')"
}
run "(ي) «نسيت» يعود إلى نصف الصفّ" flexible_back

run "(ك) الأيقونةُ تعود إلى القوس" sub "$AUTH" \
  "crest: const AuthCrest()," \
  "crest: Image.asset('assets/brand/app_mark.png', width: 68, height: 68),"

# ── القفل ───────────────────────────────────────────────────────────────────
run "(ل) أرقامٌ هنديّة" sub "$LOCK" \
  "                          Text(
                            label,
                            style: TextStyle(
                              fontSize: digit,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent," \
  "                          Text(
                            '٠١٢٣٤٥٦٧٨٩'[int.parse(label)],
                            style: TextStyle(
                              fontSize: digit,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,"

run "(م) المفاتيحُ مربّعات" sub "$LOCK" \
  ": const CircleBorder(side: BorderSide(color: authGoldLine))," \
  ": const RoundedRectangleBorder(side: BorderSide(color: authGoldLine)),"

# **ومرساةُ الحذف تبدأ بقوس البصمة:** `key('0')` ثمّ `key('back'` في `_Pad`
# ورقةِ الضبط أيضاً — فطابقت مرّتين في أوّل تشغيلٍ ولم يقع الكسر.
zero_first() {
  sub "$LOCK" "              children: [
                if (bio == null)" "              children: [
                key('0'),
                if (bio == null)" &&
  sub "$LOCK" "                  ),
                key('0'),
                key(" "                  ),
                key("
}
run "(ن) البصمةُ يسارَ الصفر" zero_first

run "(س) لا خانةَ فارغةَ بلا بصمة" sub "$LOCK" \
  "                  SizedBox(width: w)
                else" "                  const SizedBox.shrink()
                else"

run "(ع) النقاطُ بلا ذهب" sub "$LOCK" \
  "ring: authGoldEdge," "ring: AppColors.hairline,"

run "(ف) ورقةُ الضبط تأخذ اللوحةَ الجديدة" sub "$LOCK" \
  "            _Pad(
              busy: false," "            _RingPad(
              busy: false,"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
