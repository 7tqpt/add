#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحارس الحماية الشامل (`rls_coverage.test.mjs`).
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وهذا أوّلُ ضابطٍ سالبٍ للقاعدة.** كان للتطبيق ضوابطُه وللوحة ضوابطُها،
# والقاعدةُ — وهي الحرزُ الأخير — بلا واحد.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE=rls_coverage.test.mjs
I=../install.sql
A=../apply.sql
R=../roles.sql

BACKUP=$(mktemp -d)
cp "$I" "$BACKUP/i"; cp "$A" "$BACKUP/a"; cp "$R" "$BACKUP/r"
restore() { cp "$BACKUP/i" "$I"; cp "$BACKUP/a" "$A"; cp "$BACKUP/r" "$R"; }
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
  if node "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if node "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── أ) جدولٌ يسقط من قائمة الحماية ──────────────────────────────────────────
#
# **وهذا هو العطبُ الذي كُتب الحارسُ لأجله:** من أضاف جدولاً ونسي اسمَه في
# القائمة خرج جدولُه مكشوفاً لكلّ زائرٍ بلا حساب.
run "(أ) جدولٌ خارجَ قائمة الحماية" \
  sub "$I" \
"    'notifications', 'push_notifications', 'daily_metrics', 'app_versions'," \
"    'notifications', 'push_notifications', 'app_versions',"

# ── ب) وجدولٌ محميٌّ بلا سياسةٍ واحدة ───────────────────────────────────────
#
# يردّ الجميعَ فتقف ميزةٌ ولا يُعرف لماذا. و`daily_metrics` لها سياسةٌ واحدة،
# فتُحوَّل إلى جدولٍ آخرَ فتبقى هي بلا شيء.
#
# **والكسرُ في `roles.sql` لا في `install.sql`:** الاسمُ نفسُه يُنشأ في
# الملفّين، والأخيرُ يغلب. فكسرُ الأوّل وحدَه لا يُنقص شيئاً — وقد جُرّب
# فبقيت الحزمةُ خضراء.
run "(ب) جدولٌ محميٌّ بلا سياسة" \
  sub "$R" \
"create policy metrics_admin_only on public.daily_metrics" \
"create policy metrics_admin_only on public.app_settings"

# ── ج) وطريقةُ عرضٍ بلا security_invoker ────────────────────────────────────
#
# تعمل بصلاحيات مالكها فتلتفّ حول RLS كلِّها — وهي البابُ الخلفيُّ الوحيدُ
# الذي يُبطل ما فوقه.
run "(ج) طريقةُ عرضٍ بصلاحيات مالكها" \
  sub "$A" \
"create view public.v_admin_providers
with (security_invoker = true) as" \
"create view public.v_admin_providers as"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
