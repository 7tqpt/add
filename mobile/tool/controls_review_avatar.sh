#!/usr/bin/env bash
# ضوابطُ سالبةٌ لوصول صورة صاحب الرأي إلى قرصه في الشاشة.
#
# تكسر كلَّ ضمانةٍ كسراً واحداً وتتأكّد أنّ الحزمةَ تحمرّ. وما لا يسقط
# بالكسر ضمانةٌ كاذبةٌ تُطمئن ولا تحرس.
#
# **وحدودُ الخادم تُقاس في موضعها لا هنا**: `supabase/tests/review_avatars.test.mjs`
# وضوابطُه يقيسان ما تُخرجه `api_provider_reviews` في قاعدةٍ حقيقيّة. وهذه
# تقيس ما يصل الشاشةَ منه.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "لا flutter في المسار"; exit 1; }

SUITE="test/review_avatar_test.dart"

P=lib/src/screens/provider_public.dart
M=lib/src/data/models.dart

FILES=("$P" "$M")
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

# ── أ) يعود القرصُ حرفاً أبداً ─────────────────────────────────────────────
#
# **وهو الحالُ الذي شُكي منه بعينه**: القرصُ في مكانه، والاسمُ صحيح، ولا صورة.
run "(أ) القرصُ يعود حرفاً" \
  sub "$P" \
"                      ProviderAvatar(
                        name: r.userName,
                        imageUrl: Api.avatarUrl(r.avatarPath),
                        size: 30,
                      )," \
"                      ProviderAvatar(name: r.userName, size: 30),"

# ── ب) وتُعطى الآراءُ كلُّها صورةَ أوّلها ──────────────────────────────────
#
# سطرٌ يُنسخ ويبقى فيه ثابتٌ. ولا يكشفه اختبارٌ يسأل «أثَمّ صورة؟» — ثمّ صورةٌ
# في الحالين، وهي صورةُ رجلٍ فوق اسم امرأة.
run "(ب) صورةُ الأوّل للجميع" \
  sub "$P" \
"                        imageUrl: Api.avatarUrl(r.avatarPath)," \
"                        imageUrl: Api.avatarUrl(rows.first.avatarPath),"

# ── ج) ويُطلب رابطٌ لمسارٍ فارغ ────────────────────────────────────────────
#
# `Image.network('')` تسقط إلى `errorBuilder` — فيومض الحرفُ بعد محاولةٍ بدل
# أن يُرسم من أوّله. وأسوأُ منه على شبكةٍ بطيئة: قرصٌ فارغٌ ينتظر لا شيء.
run "(ج) رابطٌ لمسارٍ فارغ" \
  sub "$P" \
"                        imageUrl: Api.avatarUrl(r.avatarPath)," \
"                        imageUrl: 'https://x.invalid/\${r.avatarPath}',"

# ── د) ولا يُقرأ المسارُ من صفّ الخادم ─────────────────────────────────────
#
# البابُ الذي تدخل منه الصورةُ كلُّها. ولو سقط لَعاد كلُّ شيءٍ حرفاً والشيفرةُ
# فوقه سليمةٌ تماماً — وهذا أخبثُ أنواع العطب.
run '(د) `Review.fromMap` لا تقرأ المسار' \
  sub "$M" \
"    createdAt: (m['created_at'] ?? '') as String,
    avatarPath: (m['avatar_path'] ?? '') as String,
  );
}

/// خدمةٌ يملكها مقدّم الخدمة" \
"    createdAt: (m['created_at'] ?? '') as String,
    avatarPath: '',
  );
}

/// خدمةٌ يملكها مقدّم الخدمة"

echo
echo "الساقط: $PASS — الباقي: $FAIL"
[ "$FAIL" = 0 ]
