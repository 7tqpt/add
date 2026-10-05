#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«أكمل ملفك» على صورة صاحب المنصّة — الإطارُ ومفتاحُ الدولة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/onboarding_design_test.dart test/onboarding_test.dart test/signup_fields_test.dart test/auth_frame_test.dart"
O=lib/src/screens/onboarding.dart
F=lib/src/ui/auth_frame.dart
P=lib/src/core/phone.dart

BACKUP=$(mktemp -d)
cp "$O" "$BACKUP/o"; cp "$F" "$BACKUP/f"; cp "$P" "$BACKUP/p"
restore() { cp "$BACKUP/o" "$O"; cp "$BACKUP/f" "$F"; cp "$BACKUP/p" "$P"; }
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

# ── الشكل ───────────────────────────────────────────────────────────────────
run "(أ) الرأسُ بطولِ الدخول" sub "$O" \
  "      compact: true,
      crowned: true," "      crowned: true,"

run "(ب) البطاقةُ بلا حافّةٍ مرتفعة" sub "$O" \
  "      compact: true,
      crowned: true," "      compact: true,"

# **والسطرُ في موضعين** منذ «اقفل تطبيقك» (#143): القوسُ في البطاقة، ونسختُه
# فوق الورد (`crestOnTop`). فطابقت المرساةُ مرّتين ولم يقع الكسرُ — فيُكسران معاً.
tail_both() {
  python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "padding: EdgeInsets.fromLTRB(12, compact ? 26 : 34, 12, compact ? 62 : 44),"
if s.count(old) != 2:
    print(f"   ✗ المرساةُ تطابق {s.count(old)} مرّة — لا كسرَ وقع"); sys.exit(1)
open(p, 'w', encoding='utf-8').write(s.replace(old, "padding: EdgeInsets.fromLTRB(12, compact ? 26 : 34, 12, 44),"))
PY
}
run "(ج) ذيلُ «ي» تحت البطاقة" tail_both

run "(د) القلبُ يسارَ الشخص" sub "$O" \
  "        Positioned(
          right: 14," "        Positioned(
          left: 14,"

run "(هـ) الرموزُ في آخر الحقول" sub "$O" \
  "    prefixIcon: Icon(icon, color: AppColors.ink2),
    suffixIcon: trailing," "    prefixIcon: trailing,
    suffixIcon: Icon(icon, color: AppColors.ink2),"

# **وكان الكسرُ الأوّلُ هنا فراغاً فوق الزرّ** فطالت البطاقةُ معه وبقي فيها
# — كسرٌ خاطئٌ لا ضمانةٌ كاذبة. والصحيحُ يُخرجه منها بعينه.
signout_out() {
  python3 - "$O" <<'PY3'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = """      TextButton(
        onPressed: () => widget.session.signOut(),"""
b = """          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
"""
if s.count(a) != 1 or s.count(b) != 1:
    sys.exit(1)
s = s.replace(a, "      Transform.translate(offset: const Offset(0, 600), child: " + a.lstrip(), 1)
s = s.replace(b, b + "      ),\n", 1)
open(p, 'w', encoding='utf-8').write(s)
PY3
}
run "(و) «تسجيل الخروج» خارجَ البطاقة" signout_out

run "(ز) لا مفتاحَ ابتداءً" sub "$O" \
  "  String? _dial = '967';" "  String? _dial;"

run "(ح) السهمُ لا يفتح شيئاً" sub "$O" \
  "    enabled: enabled,
    tooltip: tr('مفتاح الدولة')," "    enabled: false,
    tooltip: tr('مفتاح الدولة'),"

run "(ط) الصفرُ لا يُسقط" sub "$P" \
  "  final local = s.startsWith('0') ? s.substring(1) : s;" \
  "  final local = s;"

run "(ي) مفتاحٌ ثانٍ فوق ما كُتب بمفتاحه" sub "$P" \
  "  if (keyed) return normalisePhone(raw);" ""

run "(ك) «دولة أخرى» تنسب الرقمَ إلى اليمن" sub "$P" \
  "  if (dial == null) return keyed ? normalisePhone(raw) : null;" \
  "  if (dial == null) return normalisePhone(raw);"

run "(ل) الشاشةُ لا تجمع الرقمَ إلى مفتاحه" sub "$O" \
  "    final phone = composePhone(_dial, _phone.text);" \
  "    final phone = normalisePhone(_phone.text);"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
