#!/usr/bin/env bash
# ضوابطُ سالبةٌ لغلاف الملفّ الشخصيّ.
#
# **وما لا يسقط بالكسر ضمانةٌ كاذبة.** يُكسر الشيءُ كسراً واحداً في كلّ مرّة
# ويُنظر أتحمرّ الحزمة. وأدقُّها ثلاثة: أنّ الغلافَ **يصل الخادمَ** لا الحقلَ
# وحدَه، وأنّ أسماء الرفع الأربعة **لا تتشارك اسماً** فيمحو رفعٌ رفعاً،
# وأنّ الاسمَ صار حبراً داكناً بعد أن صارت أرضيّتُه بيضاء.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE=test/profile_cover_test.dart
K=lib/src/ui/kit.dart
A=lib/src/screens/account.dart
P=lib/src/screens/provider_profile.dart
U=lib/src/screens/provider_public.dart
I=lib/src/data/api.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
for f in "$K" "$A" "$P" "$U" "$I" "$D"; do cp "$f" "$BACKUP/$(basename "$f")"; done
restore() { for f in "$K" "$A" "$P" "$U" "$I" "$D"; do cp "$BACKUP/$(basename "$f")" "$f"; done; }
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
  if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 300 flutter test "$SUITE" >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== الضوابط =="

# أ) **الغلافُ لا يُرفع أصلاً** — يبقى التدرّجُ مهما رُفع. وهو الكسرُ الذي
#    يجعل الميزةَ كلَّها زينةً في الشيفرة لا شيء منها على الشاشة.
run "أ) الغلافُ لا يُعرض" sub "$K" \
  "    final link = url;
    return Stack(" \
  "    final String? link = null;
    return Stack("

# ب) **والقرصُ لا يطلّ على حافّته** — فيصير الشكلُ غيرَ الذي اختاره صاحبُ
#    المنصّة: شريطٌ ثمّ قرصٌ تحته، لا قرصٌ يقطع الحافّة.
run "ب) القرصُ لا يطلّ" sub "$K" \
  "                SizedBox(height: band - profileAvatarSize / 2)," \
  "                SizedBox(height: band),"

# ج) **والاسمُ يبقى أبيضَ كما كان على الرأس النبيذيّ** — فيخرج أبيضُ على
#    أبيض. وهذا أخطرُ ما يقع حين تنقلب أرضيّةُ عنصرٍ ولا ينقلب حبرُه.
run "ج) الاسمُ أبيضُ على أبيض" sub "$K" \
  "                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink," \
  "                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: OnAccent.ink,"

# د) **والزرُّ يُعرض في رأسٍ لا يملك رفعاً** — يُضغط فلا يقع شيء.
run "د) زرٌّ بلا رفع" sub "$K" \
  "        if (onEdit != null)" \
  "        if (true)"

# هـ) **ولا يُعطَّل والرفعُ جارٍ** — ضغطتان ترفعان مرّتين، والثانيةُ قد تسبق
#     الأولى فيبقى القديم وصاحبُه يظنّ الجديدَ حُفظ.
run "هـ) يُضغط والرفعُ جارٍ" sub "$K" \
  "      child: _CoverButton(onTap: busy ? null : onEdit, busy: busy)," \
  "      child: _CoverButton(onTap: onEdit, busy: busy),"

# و) **والزرُّ في جهة القرص** — فيختفي تحته. وقد اختفى فعلاً في أوّل رسمٍ
#    للمقترح، ولم يظهر إلّا بالنظر في الصورة.
run "و) الزرُّ تحت القرص" sub "$K" \
  "            end: Space.lg,
            child: _CoverButton" \
  "            start: Space.lg,
            child: _CoverButton"

# ز) **وحسابُ العميل بلا غلاف** — نصفُ ما طلبه صاحبُ المنصّة: «العميل او
#    مقدم الخدمة».
run "ز) العميلُ بلا غلاف" sub "$A" \
  "          onEditCover: profile == null ? null : () => _changeCover(profile)," \
  "          onEditCover: null,"

# ح) **وملفُّ المزوّد بلا غلاف** — والنصفُ الآخر.
run "ح) المزوّدُ بلا غلاف" sub "$P" \
  "              onEditCover: () => _changeCover(p)," \
  "              onEditCover: null,"

# ط) **وسطرُ الحال العالقة يبقى أبيضَ** — وهو السطرُ الذي يقول لصاحب القاعة
#    إنّ طلبَه لم يُقبل وإنّه لن يستقبل حجزاً واحداً. **وهذا عيبٌ وقع فعلاً**
#    حين قُلبت أرضيّةُ الرأس، ولم يكن له ضابطٌ قبل اليوم.
run "ط) سطرُ الحال أبيضُ على أبيض" sub "$P" \
  "              color: AppColors.ink2," \
  "              color: OnAccent.ink,"

# ي) **وصفحةُ المزوّد العامّة تُهمل العمود** — يرفع صاحبُ القاعة غلافَه فيراه
#    في شاشته هو، ولا يراه عميلٌ واحد. وهذا ما لا تكشفه الشجرةُ في الوضع
#    التجريبيّ، فيُسأل الملفّ.
run "ي) العامّةُ لا تقرأ العمود" sub "$U" \
  "            child: _CoverArt(url: Api.avatarUrl(p.coverPath))," \
  "            child: const _CoverArt(url: null),"

# ك) **والغلافُ لا يصل الخادمَ وهو معروضٌ في الشاشة** — وهذا هو الكذبُ الذي
#    لا يكشفه سؤالُ الحقل عمّا فيه.
run "ك) غلافُ العميل لا يصل" sub "$D" \
  "    coverPath: cover," \
  ""

run "ل) غلافُ المزوّد لا يصل" sub "$I" \
  "      'cover_path': ?coverPath," \
  ""

# م) **ورفعُ الغلاف يكتب فوق صورة الملفّ** — الاسمُ واحدٌ و`upsert` يمحو بلا
#    سؤال، فيفقد صاحبُه صورتَه وهو يظنّ أنّه أضاف غلافاً.
run "م) الغلافُ يمحو الصورة" sub "$I" \
  "    final path = '\$authUserId/cover.\$ext';" \
  "    final path = '\$authUserId/avatar.\$ext';"

run "ن) غلافُ المزوّد يمحو شعارَه" sub "$I" \
  "    final path = '\$authUserId/provider_cover.\$ext';" \
  "    final path = '\$authUserId/provider.\$ext';"

echo; echo "== الحصيلة: $PASS سقطت، $FAIL لم تسقط =="
[ "$FAIL" -eq 0 ]
