#!/usr/bin/env bash
# ضوابطُ سالبةٌ لـ«تأكيد رقمك» على صورتي صاحب المنصّة — الرقمُ كاملاً،
# وشعارُ واتساب بلونه، و«رمز التأكيد» داخلَ الخانة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ، **وتطبع ما سقط**.
#
# **ولا يُشغَّل `flutter test` بيدٍ أخرى وهذا يعمل**: السكربتُ يبدّل `lib/`.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/verify_phone_design_test.dart test/verify_phone_test.dart test/i18n_test.dart"
V=lib/src/screens/verify_phone.dart
W=lib/src/ui/whatsapp_mark.dart
P=lib/src/core/phone.dart

BACKUP=$(mktemp -d)
cp "$V" "$BACKUP/v"; cp "$W" "$BACKUP/w"; cp "$P" "$BACKUP/p"
restore() { cp "$BACKUP/v" "$V"; cp "$BACKUP/w" "$W"; cp "$BACKUP/p" "$P"; }
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

# ── (أ) الرقمُ كاملاً ─────────────────────────────────────────────────────
run "(أ) خاناتٌ مخفيّة" sub "$V" \
  "    final shown = displayPhone(phone);" \
  "    final shown = displayPhone(phone).replaceRange(7, 12, '•• ••');"

run "(ب) علمُ اليمن على كلّ رقم" sub "$V" \
  "          if (shown.startsWith('+967'))" "          if (true)"

run "(ج) الرقمُ بلا تقسيم" sub "$P" \
  "      return '+\$key \${local.substring(0, 3)} \${local.substring(3, 6)} \${local.substring(6)}';" \
  "      return s;"

# ── (أ) شعارُ واتساب بلونه ───────────────────────────────────────────────────
run "(د) الشعارُ بلوننا لا لونه" sub "$V" \
  "        WhatsAppMark(size: 44)," "        WhatsAppMark(size: 44, color: AppColors.accent),"

run "(هـ) الشعارُ على النبيذيّ مباشرة" sub "$V" \
  "decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)," \
  "decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),"

run "(و) الحلقةُ مصمتةٌ بلا فراغ" sub "$W" \
  "  return path;" "  return Path()..addRect(const Rect.fromLTWH(0, 0, 24, 24));"

# ── (أ) «رمز التأكيد» داخلَ الخانة ───────────────────────────────────────────
run "(ز) العنوانُ فوق الخانة" sub "$V" \
  "              labelText: tr('رمز التأكيد')," \
  "              labelText: tr('رمز التأكيد'),
              floatingLabelBehavior: FloatingLabelBehavior.always,"

# ── والباقي من صورته ─────────────────────────────────────────────────────────
run "(ح) «تأكيد رقمك» يغيب من الرأس" sub "$V" \
  "        tr('تأكيد رقمك')," "        tr('فرحتي'),"

run "(ط) السطرُ القديمُ تحت الزرّ" sub "$V" \
  "          tr('نستخدم رقمك لتأكيد حجوزاتك والتواصل معك فقط')," \
  "          tr('أرسل الرمز على واتساب'),"

run "(ي) عنوانُ الخطوة الثانية كالأولى" sub "$V" \
  "          _sent ? tr('أدخل رمز التأكيد') : tr('رقمك يؤكَّد مرّةً واحدة')," \
  "          tr('رقمك يؤكَّد مرّةً واحدة'),"

echo
echo "سقط $PASS — ولم يسقط $FAIL"
[ "$FAIL" = 0 ]
