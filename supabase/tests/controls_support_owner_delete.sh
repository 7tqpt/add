#!/usr/bin/env bash
# ضوابطُ سالبةٌ لحذف صاحب التذكرة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وأخطرُ ما يُكسر هنا (أ): تُشال كتلةُ إصلاحِ القاعدة القائمة.** وقاعدةُ
# الإنتاج قائمةٌ منذ زمن: فيها المفتاحُ `set null` تحت قيدٍ يمنع الفراغ، فلا
# يسقط المسحُ وحدَه بل **كلُّ من فتح تذكرةً مرّةً لا يستطيع حذفَ حسابه** —
# برسالةِ خطأٍ من Postgres لا يفهمها. وحذفُ الحساب شرطٌ عند المتجرين.
set -uo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "لا node في المسار"; exit 1; }

SUITE="support_owner_delete.test.mjs support.test.mjs"
F=../support.sql
S=../seed.sql

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$S" "$BACKUP/s"
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/s" "$S"; }
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
  if timeout 400 node --test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 400 node --test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# ── ملاحظةٌ قبل الضوابط: أين تُحرَس هذه الضمانة ────────────────────────────
#
# **كسرُ تعريفِ العمود وحدَه لا يُسقط شيئاً — جرّبتُه فبقيت الحزمةُ خضراء.**
# وليس ذلك نقصاً في القياس: كتلةُ الإصلاح تلي التعريفَ في الملفّ نفسِه،
# فتُصلح ما أفسده التعريفُ في القاعدة الجديدة كما تُصلح القديمة. فالضمانةُ
# لها موضعُ حراسةٍ واحدٌ حقيقيّ — تلك الكتلة — والضوابطُ تُوجَّه إليها.
#
# ── أ) كتلةُ الإصلاح تُشال ──────────────────────────────────────────────────
#
# **وهذا أخطرُها.** قاعدتُه هو أُنشئت قبل الإصلاح، و`create table if not
# exists` لا تمسّ جدولاً موجوداً — فبلا هذه الكتلة يبقى التضادُّ فيها وإن
# أعاد تنفيذ الملفّ مئةَ مرّة.
run "(أ) لا إصلاحَ لقاعدةٍ قائمة" \
  sub "$F" \
"      and con.confdeltype <> 'c'          -- 'c' = cascade: ما أُصلح لا يُعاد" \
"      and false"

# ── ب) وتُصلح ما هو سليمٌ وتترك المكسور ─────────────────────────────────────
#
# انقلابُ الشرط: تمرّ الكتلةُ على المفاتيح الصحيحة وتتخطّى ما يجب إصلاحه.
# **ولا يسقط هذا بقاعدةٍ جديدة** — الجديدةُ لا شيءَ فيها ليُصلَح.
run "(ب) يُصلَح السليمُ ويُترك المكسور" \
  sub "$F" \
"      and con.confdeltype <> 'c'          -- 'c' = cascade: ما أُصلح لا يُعاد" \
"      and con.confdeltype = 'c'"

# ── ج) والإصلاحُ يتناول عموداً ويترك الآخر ──────────────────────────────────
#
# نصفُ إصلاح: يُحذف الحسابُ ولا يُحذف مقدّمُ الخدمة. **ولا يسقط هذا باختبارٍ
# يقيس وجهاً واحداً** — ولذلك قيس الوجهان على القاعدة القديمة.
run "(ج) يُصلَح مفتاحُ المستخدم وحدَه" \
  sub "$F" \
"      and att.attname in ('user_id', 'provider_id')" \
"      and att.attname in ('user_id')"

# ── د) ويُعاد المفتاحُ كما كان: `set null` ──────────────────────────────────
#
# الكتلةُ تعمل وتحذف وتُعيد — وتُعيد العطلَ نفسَه. وهو أخبثُ من إشالتها:
# يُرى في السجلّ أنّ الإصلاحَ جرى.
run "(د) الإصلاحُ يُعيد `set null`" \
  sub "$F" \
"        foreign key (user_id) references public.app_users (id) on delete cascade;" \
"        foreign key (user_id) references public.app_users (id) on delete set null;"

# ── هـ) وكذلك في وجه مقدّم الخدمة ───────────────────────────────────────────
run "(هـ) الإصلاحُ يُعيد `set null` لمقدّم الخدمة" \
  sub "$F" \
"        foreign key (provider_id) references public.service_providers (id)
        on delete cascade;" \
"        foreign key (provider_id) references public.service_providers (id)
        on delete set null;"

# ── و) والقيدُ يُشال بدل إصلاح المفتاح ──────────────────────────────────────
#
# **و«إصلاحٌ» كهذا يمرّ على من يقيس نجاحَ الحذف وحدَه:** لو حُذف
# `ticket_has_owner` لَنجح الحذفُ ولَبقيت تذكرةٌ يتيمةٌ لا يُردّ عليها — وهو
# ما رفضه صاحبُ المنصّة حين اختار (أ): تذهب التذكرةُ مع صاحبها.
run "(و) يُشال القيدُ وتبقى التذكرةُ يتيمة" \
  sub "$F" \
"  constraint ticket_has_owner
    check (user_id is not null or provider_id is not null)" \
"  constraint ticket_has_owner
    check (true)"

# ── ز) ومسحُ البيانة لا يسأل عن وجود الجدول ─────────────────────────────────
#
# قاعدةٌ لم يُنفَّذ عليها `support.sql` ليس فيها هذان الجدولان — وحذفٌ صريحٌ
# بلا سؤالٍ يُسقط البيانةَ كلَّها على قاعدةٍ سليمة.
run "(ز) يُحذف بلا سؤالٍ عن الوجود" \
  sub "$S" \
"  if to_regclass('public.support_messages') is not null then
    delete from public.support_messages where true;
  end if;" \
"  delete from public.support_messages where true;"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
