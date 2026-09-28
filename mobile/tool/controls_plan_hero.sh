#!/usr/bin/env bash
# ضوابطُ سالبةٌ لرأس «خطة العرس»: صورةٌ وعدٌّ تنازليٌّ وشريطُ تقدّم.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وكسرٌ يُسقط الحزمةَ بعطبٍ في الترجمة ضابطٌ كاذبٌ كذلك**: يحمرّ لسببٍ غير
# الذي يدّعيه. فكلُّ كسرٍ هنا يُتحقَّق من وقوعه أوّلاً (المرساةُ تطابق مرّةً
# واحدة)، والسطرُ المكسورُ Dart صحيحٌ يُصرَّف.
#
# **وحرزُ القاعدة يُضبط في مكانه** — `supabase/tests/controls_plan_cover.sh`
# يكسر `plan_cover.sql` سبعةَ كسور. ولا يُغني أحدُهما عن الآخر.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/plan_test.dart test/plan_money_test.dart test/list_motion_test.dart"
F=lib/src/screens/plan.dart
# **و`BigNumberIn` انتقلت إلى العدّة** (`kit.dart`) لتُقرأ في الشاشتين،
# فمراسي أسلوبها هناك لا هنا. وقد بقيت ثلاثةُ ضوابطَ تشير إلى موضعها
# القديم فلم تقع أصلاً — وهذا ضابطٌ كاذبٌ يُطمئن ولا يحرس.
K=lib/src/ui/kit.dart
D=lib/src/data/demo.dart

BACKUP=$(mktemp -d)
cp "$F" "$BACKUP/f"; cp "$K" "$BACKUP/k"; cp "$D" "$BACKUP/d"
# **وكلُّ ملفٍّ يُكسر يُستعاد.** أُضيف `$K` إلى النسخ ونُسي من الاستعادة،
# فترك آخرُ تشغيلٍ `demo.dart` مكسوراً في الشجرة — واحمرّت بعده اختباراتٌ
# لا علاقةَ لها بما كان يُقاس. فالثلاثةُ هنا جملةً واحدة.
restore() { cp "$BACKUP/f" "$F"; cp "$BACKUP/k" "$K"; cp "$BACKUP/d" "$D"; }
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
  if timeout 900 flutter test $SUITE >/dev/null 2>&1; then
    echo "✗ $name — الحزمةُ خضراءُ والضمانةُ مكسورة"; FAIL=$((FAIL+1))
  else
    echo "✓ $name — سقط"; PASS=$((PASS+1))
  fi
  restore
}

echo "== الأساس =="
if timeout 900 flutter test $SUITE >/dev/null 2>&1; then echo "أخضر."
else echo "الأساسُ أحمر — لا معنى للضوابط."; exit 1; fi

echo; echo "== العدُّ التنازلي =="

# ── أ) يُسوّى الرقمُ بجيرانه ──────────────────────────────────────────────
#
# **والحجمُ جزءٌ من المعنى**: العدُّ التنازليُّ أوّلُ ما يُسأل عنه، ورقمٌ
# بحجم الكلمة المجاورة يمرّ عليه النظرُ ولا يلتقطه.
run "(أ) الرقمُ بحجم جيرانه" \
  sub "$K" \
"    const big = TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700);" \
"    const big = TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w700);"

# ── ب) ويُحسب الرقمُ في الشاشة لا يُؤخذ من `countdownLabel` ───────────────
#
# **وحسابان للرقم نفسِه يفترقان ولا يُنتبه**: صيغةُ العدد العربيّة أربعٌ،
# و`countdownLabel` تحسبها. ومن كتب `'بقي $days يوماً'` أخرج «بقي 2 يوماً»
# و«بقي 11 يوماً» — وكلاهما خطأ.
run "(ب) الجملةُ تُركَّب في الشاشة لا تُؤخذ" \
  sub "$F" \
"            BigNumberIn(countdownLabel(days), color: AppColors.goldOnBrand)," \
"            BigNumberIn('بقي \${days ?? 0} يوماً', color: AppColors.goldOnBrand),"

# ── ب٢) ويُعلَن احتياطيُّ الخطّ في أسلوب القِطعة ──────────────────────────
#
# **وهذا عطبٌ وقع فعلاً وخرج في لقطة.** قِطعةٌ تُعلن `fontFamilyFallback`
# بلا `fontFamily` تُلغي عائلةَ الخطّ الموروثةَ من الثيمة، فيخرج الرقمُ
# مربّعاً مصمتاً. والنصُّ والحجمُ كلاهما سليمٌ في الشجرة، فلا يكشفه إلّا
# سؤالٌ عن الأسلوب نفسِه.
run "(ب٢) احتياطيُّ الخطّ في أسلوب القِطعة" \
  sub "$K" \
"    const big = TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700);" \
"    const big = TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700,
      fontFamilyFallback: arabicFallback);"

echo; echo "== وشريطُ التقدّم =="

# ── ج) وتُكتب النسبةُ لا تُحسب ────────────────────────────────────────────
run "(ج) النسبةُ مكتوبةٌ لا محسوبة" \
  sub "$F" \
"                label: trf('{0}٪', ['\${progress.percent}'])," \
"                label: trf('{0}٪', ['60']),"

# ── د) ويُقاس الشريطُ بغير النسبة ─────────────────────────────────────────
#
# فيُقرأ الرقمُ شيئاً ويُرى الشريطُ شيئاً آخر — وهما في سطرين متجاورين.
run "(د) الشريطُ لا يتبع النسبة" \
  sub "$F" \
"                    key: const ValueKey('plan-bar'),
                    value: progress.percent / 100," \
"                    key: const ValueKey('plan-bar'),
                    value: 0.6,"

# ── د٢) والحلقةُ لا تتبع النسبة ───────────────────────────────────────────
#
# **والعينُ تصدّق القوسَ قبل أن تقرأ الرقم**: حلقةٌ ممتلئةٌ بغير نسبتها
# تقول غيرَ ما يقوله جوفُها، وهما في موضعٍ واحد.
run "(د٢) الحلقةُ لا تتبع النسبة" \
  sub "$F" \
"                value: progress.percent / 100,
                label: trf('{0}٪', ['\${progress.percent}'])," \
"                value: 0.6,
                label: trf('{0}٪', ['\${progress.percent}']),"

# ── هـ) ويُعدّ المنجَزُ من الكلّ لا من المشطوب ────────────────────────────
run "(هـ) عددُ المنجَز مكتوب" \
  sub "$F" \
"                          '\${progress.tasksDone}'," \
"                          '6',"

# ── و) ويُقال «أنت على الطريق الصحيح» لمن لم يبدأ ─────────────────────────
#
# **وعبارةٌ تُقال في كلّ حالٍ لا تقول شيئاً**: من فتح خطّتَه ولم يشطب مهمّةً
# يُقرأ عليه أنّه ماضٍ في طريقه.
run "(و) سطرُ التشجيع ثابتٌ لا يتبع الحال" \
  sub "$F" \
"    if (progress.tasksTotal == 0) return tr('لم تُفتح قائمة التجهيز بعد');" \
"    if (progress.tasksTotal < 0) return tr('لم تُفتح قائمة التجهيز بعد');"

echo; echo "== وتتابعُ الأقسام =="

# ── ز) وتقع الأقسامُ دفعةً واحدة ──────────────────────────────────────────
run "(ز) الأقسامُ تقع دفعةً واحدة" \
  sub "$F" \
"                FadeSlideIn(index: 3, child: _MoneyCard(plan: p, onEdit: widget.onEdit))," \
"                _MoneyCard(plan: p, onEdit: widget.onEdit),"

echo; echo "== ومصدرُ الغلاف =="

# ── ح) ويُؤخذ غلافُ أيِّ حجزٍ لا الأقدم ───────────────────────────────────
#
# **والترتيبُ هو الضمانة**: بلا فرزٍ يتبدّل رأسُ الخطّة بين فتحةٍ وفتحةٍ
# بحسب ترتيبِ ما وصل — وصورةٌ تتبدّل بلا سببٍ تُقرأ عطباً.
#
# ويقع الكسرُ في `demo.dart` لأنّ وضعَ العرض مصدرُ الأرقام في الاختبار،
# وكسرُه يُثبت أنّ الاختبارَ يقرأ ما يُحسب لا ما يُكتب.
run "(ح) الغلافُ من غير الأقدم حجزاً" \
  sub "$D" \
"    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));" \
"    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));"

# ── ط) ويُورث الملغى رأسَ الخطّة ──────────────────────────────────────────
run "(ط) الملغى يُعطي غلافاً" \
  sub "$D" \
"          b.status != BookingStatus.cancelled &&" \
"          true &&"

echo; echo "== وخَتمُ القائمة =="

# ── م) ويُترك من أتمّ المهامَّ كلَّها بفراغ ─────────────────────────────
#
# **قائمةٌ تخلو فجأةً تُقرأ عطباً لا إنجازاً** — «أين مهامّي؟». وموضعُ
# المهامّ الذاهبةِ يُملأ بخَتمٍ، على تصميمٍ أرسله صاحبُ المنصّة.
run "(م) لا خَتمَ لمن أتمّ كلَّ شيء" \
  sub "$F" \
"                    if (left.isEmpty && tasks.isNotEmpty) const _AllDone()," \
"                    if (left.isEmpty && tasks.isEmpty) const _AllDone(),"

# ── ن) وقرصُ الموعد يعرض المحافظةَ في التاريخ ──────────────────────────
#
# فيُقرأ اسمُ المحافظة جزءاً من التاريخ — وكانا كذلك قبل تصميمه.
run "(ن) المحافظةُ ملصوقةٌ بالتاريخ" \
  sub "$F" \
"          Flexible(child: _PillText(date)),
          if (place.isNotEmpty) ...[" \
"          Flexible(
            child: _PillText(place.isEmpty ? date : '\$date · \$place'),
          ),
          if (place.isEmpty) ...["

# ── س) ويعود العدُّ التنازليُّ بالذهب العاديّ ───────────────────────────
#
# **وهو ذهبٌ مقيسٌ على الفاتح**: على تدرّج الصدر الطَّفليّ يعطي ‎١٫١٩:١‎ —
# فيخرج العدُّ داكناً لا يكاد يُرى. وقد خرج كذلك في أوّل رسمةٍ للوح.
run "(س) العدُّ التنازليُّ بذهبٍ لا يُقرأ على الصدر" \
  sub "$F" \
"            BigNumberIn(countdownLabel(days), color: AppColors.goldOnBrand)," \
"            BigNumberIn(countdownLabel(days)),"

# ── ع) ويعود الغلافُ لوحاً يجاور النصّ ──────────────────────────────────
#
# **فيرى من لم يحجز خدمةً لها صورةٌ مربّعاً فارغاً** — وهي حالُ كلِّ من
# فتح خطّته أوّلَ مرّة. واختار صاحبُ المنصّة أن تذوب الصورةُ في الخلفيّة.
run "(ع) الغلافُ لوحٌ يجاور لا خلفيّةٌ تذوب" \
  sub "$F" \
"    final url = Api.mediaUrl(path);
    if (url == null) return const SizedBox.shrink();
    return ShaderMask(" \
"    final url = Api.mediaUrl(path);
    if (url == null) return const ColoredBox(color: AppColors.surface2);
    return ShaderMask("

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
