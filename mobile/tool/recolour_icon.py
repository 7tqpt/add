#!/usr/bin/env python3
"""ينقل شعارَ التطبيق من الأزرق إلى ألوان الهويّة — نبيذيٌّ وذهب.

    python3 tool/recolour_icon.py                      # يكتب assets/brand/app_icon.png
    python3 tool/recolour_icon.py --out /tmp/x.png     # للمعاينة بلا مساس

ثمّ:  python3 tool/make_icons.py assets/brand/app_icon.png

── لماذا سكربتٌ لا صورةٌ تُلصق ─────────────────────────────────────────────

الأصلُ `app_icon_ai.png` يبقى كما وُلد، وهذا الملفُّ يُخرج منه النسخةَ
النبيذيّة. فالتحويلُ **يُعاد** إن تبدّلت الهويّة، ويُقرأ فيُعرف ما وقع —
بخلاف صورةٍ تُلصق فلا يعرف أحدٌ بعد شهرٍ كيف صُنعت ولا كيف تُصنع مثلُها.

── ولماذا لا يُبدَّل اللونُ لوناً بلون ────────────────────────────────────

العملُ مجسَّم: فيه قبّةٌ لها ضوءٌ من أعلى وظلٌّ في أسفلها، وحاشيةٌ لها
لمعة. ولو أُبدل كلُّ أزرقَ بنبيذيٍّ واحدٍ لَذهب المجسَّمُ كلُّه وصارت
لطخةً مسطّحة.

فيُقرأ من كلّ بكسلٍ **موضعُه في سلّم الإضاءة**، ويوضع في الموضع نفسِه من
سلّمٍ نبيذيّ. فيبقى الضوءُ ضوءاً والظلُّ ظلاًّ، ويتبدّل اللونُ وحده.

── والفضّيُّ يصير ذهباً ───────────────────────────────────────────────────

«فرحتي» والقلبُ كانا فضّيَّين على أزرق. والفضّيُّ على النبيذيّ يبرد ويشبه
الرماد، والذهبُ عليه هو عُرفُ الهويّة في التطبيق كلِّه (`goldOnAccent`).
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageFilter
except ImportError:
    sys.exit('يلزم Pillow:  pip install Pillow')

HERE = Path(__file__).resolve().parent.parent
SRC = HERE / 'assets/brand/app_icon_ai.png'
DST = HERE / 'assets/brand/app_icon.png'

# ── السلالم ────────────────────────────────────────────────────────────────
#
# مأخوذةٌ من `lib/src/core/theme.dart` بعينها لا مقرَّبةً منها: أيقونةٌ
# تقارب لونَ التطبيق ولا تطابقه تُقرأ خطأً مطبعيّاً لا اختياراً.

WINE = [                      # من الظلّ إلى الضوء
    (0x3A, 0x05, 0x14),       # أعمقُ من accentDeep — لظلّ القاع
    (0x5C, 0x08, 0x20),       # accentDeep
    (0x7B, 0x0F, 0x2E),       # accent — وهو لونُ العلامة
    (0x9A, 0x1B, 0x3E),       # accentLift
    (0xC4, 0x4A, 0x6C),       # لمعةُ الحافّة
]

GOLD = [
    (0x6B, 0x47, 0x0F),
    (0x9A, 0x6B, 0x18),       # gold
    (0xC9, 0x9F, 0x3F),
    (0xE6, 0xC4, 0x73),       # goldOnAccent
    (0xFB, 0xEF, 0xC8),       # أعلى لمعة
]


# ── مرابطُ سلّم الأزرق ─────────────────────────────────────────────────────
#
# **تُقاس من الصورة في كلّ تشغيل، ولا تُكتب أرقاماً.** رقمٌ يُثبَّت هنا
# يعتّق صامتاً إن بُدّل العملُ يوماً: يبقى السكربتُ يعمل ويخرج بلونٍ خطأ.
#
# والذي قِيس أوّلَ مرّة: الوسيطُ ‎٠٫٧٨‎ لا ‎٠٫٧٠‎ كما خمّنتُ — والفرقُ بينهما
# أخرج الأيقونةَ **ورديّةً فاقعة** لا نبيذيّة، رأيتُها في المعاينة مرّتين
# قبل أن أقيس.
#
#   · الوسيط  → `accent` نفسُه، وهو لونُ العلامة. فما يغلب على الأيقونة
#     يطابق ما يغلب على التطبيق.
#   · العُشر الأدنى → أعمقُ الظلّ،  والعُشر الأعلى → أعلى اللمعة.
#
# وأطرافُ العُشر لا الحدُّ المطلق: بكسلاتٌ شاذّةٌ في الطرفين تمطّ السلّم
# كلَّه فتُسطّح ما بينهما.
FIELD_T = 0.5         # موضعُ `accent` في السلّم


def measure_blue(im: Image.Image) -> tuple[float, float, float]:
    """يعيد (العُشر الأدنى، الوسيط، العُشر الأعلى) لإضاءة أزرق العمل."""
    small = im.convert('RGB').resize((400, 400), Image.LANCZOS)
    px = small.load()
    vs = []
    for y in range(400):
        for x in range(400):
            r, g, b = px[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            v = mx / 255
            if v < 0.12 or mx == 0 or (mx - mn) / mx < 0.20:
                continue
            if mx == r:
                hue = (60 * (((g - b) / (mx - mn)) % 6)) % 360
            elif mx == g:
                hue = 60 * (((b - r) / (mx - mn)) + 2)
            else:
                hue = 60 * (((r - g) / (mx - mn)) + 4)
            if 170 <= hue <= 265:
                vs.append(v)
    if len(vs) < 100:
        sys.exit('لا أزرقَ يُذكر في الصورة — أهي النسخةُ النبيذيّة أصلاً؟')
    vs.sort()
    return vs[len(vs) // 10], vs[len(vs) // 2], vs[len(vs) * 9 // 10]


def blue_position(v: float, lo: float, mid: float, hi: float) -> float:
    """موضعُ إضاءةِ بكسلٍ أزرقَ من السلّم النبيذيّ — بقطعتين لا بخطٍّ واحد."""
    if v <= mid:
        return FIELD_T * (v - lo) / (mid - lo) if mid > lo else 0.0
    return FIELD_T + (1 - FIELD_T) * (v - mid) / (hi - mid) if hi > mid else 1.0


def ramp(stops, t: float) -> tuple[int, int, int]:
    """لونٌ من سلّمٍ عند الموضع `t` بين ٠ و١، بمزجٍ خطّيّ بين درجتين."""
    t = min(1.0, max(0.0, t))
    span = len(stops) - 1
    i = min(span - 1, int(t * span))
    f = t * span - i
    a, b = stops[i], stops[i + 1]
    return tuple(round(a[c] + (b[c] - a[c]) * f) for c in range(3))


def blank_stray_islands(im: Image.Image) -> int:
    """يُسوِّد كلَّ كتلةٍ مضيئةٍ منفصلةٍ عن جسم العمل — والشارةُ منها.

    مولّدُ الصور يضع في هامش الصورة شارةَ «Made with AI». وقد بقيت في
    المستودع من غير أن يراها أحد: `ic_launcher.png` يُقصّ بزواياه المستديرة
    فتختفي، وطبقةُ الواجهة يقصّها قناعُ الجهاز فتختفي — **وظهرت أوّلَ ما
    ظهرت في أيقونة آيفون**، لأنّها مربّعةٌ كاملةٌ لا قناعَ لها.

    **وصندوقُ العمل لا يكفي، وقد جرّبتُه فلم يكفِ.** قِيست الشارةُ عند
    ‎y 9–49‎ وحدُّ صندوق العمل عند ‎y 34‎ — فهي تتداخل معه، ويبقى منها شريطٌ
    بعد طمس ما خرج عنه. رأيتُه في المعاينة.

    فالقاعدةُ التي تصحّ: **العملُ كتلةٌ واحدةٌ متّصلة**، والشارةُ جزيرةٌ
    يفصلها سوادُ الهامش. فتُوسم الكتلُ وتُبقى الكبرى ويُسوَّد ما عداها —
    ولا إحداثيّاتٍ تُكتب بيد فتعتّق إن بُدّل العملُ أو نُقلت الشارة.
    """
    from collections import deque

    rgba = im.convert('RGBA')
    w, h = rgba.size
    px = rgba.load()

    # التوسيمُ على شبكةٍ مصغَّرة: الجزيرةُ أكبرُ من خليّةٍ بكثير، والتصغير
    # يجعل الحساب لحظةً بدل دقائق على مليون بكسل.
    grid = 256
    sx, sy = w / grid, h / grid
    lit = [[sum(px[min(w - 1, int(gx * sx)), min(h - 1, int(gy * sy))][:3]) > 70
            for gx in range(grid)] for gy in range(grid)]

    seen = [[False] * grid for _ in range(grid)]
    blobs: list[list[tuple[int, int]]] = []
    for y0 in range(grid):
        for x0 in range(grid):
            if not lit[y0][x0] or seen[y0][x0]:
                continue
            q, cells = deque([(x0, y0)]), []
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                cells.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < grid and 0 <= ny < grid and lit[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            blobs.append(cells)

    if len(blobs) < 2:
        return 0
    blobs.sort(key=len, reverse=True)
    stray = {c for blob in blobs[1:] for c in blob}
    print(f'كتلٌ مضيئة: {len(blobs)} — تبقى الكبرى ({len(blobs[0]):,} خليّة) '
          f'ويُطمس {len(blobs) - 1}')

    # **والطمسُ بقناعٍ مكبَّرٍ مُوسَّع لا بهامشِ خليّة.** خليّةُ الشبكة
    # أربعةُ بكسلات، وهُدبُ التنعيم حول الشارة يمتدّ أبعدَ منها — فطمسُ
    # الخلايا وحدَها ترك ‎١١٦‎ بكسلاً فاتحاً، قِستُها فوجدتُها.
    keep = Image.new('L', (grid, grid), 0)
    kp = keep.load()
    for x, y in blobs[0]:
        kp[x, y] = 255
    keep = keep.resize((w, h), Image.NEAREST).filter(ImageFilter.MaxFilter(9))
    kpx = keep.load()

    wiped = 0
    for y in range(h):
        for x in range(w):
            if kpx[x, y]:
                continue
            if sum(px[x, y][:3]) > 70:
                wiped += 1
            px[x, y] = (0, 0, 0, px[x, y][3])
    im.paste(rgba)
    return wiped


def main() -> None:
    args = sys.argv[1:]
    dst = DST
    if '--out' in args:
        dst = Path(args[args.index('--out') + 1])
    src = SRC
    if not src.exists():
        sys.exit(f'لا ملف: {src}\nضع الأصلَ الأزرق فيه أوّلاً.')

    im = Image.open(src).convert('RGBA')
    lo, mid, hi = measure_blue(im)
    print(f'إضاءةُ الأزرق المقيسة — ظلٌّ {lo:.2f} · وسيطٌ {mid:.2f} · لمعةٌ {hi:.2f}')
    px = im.load()
    w, h = im.size
    moved = {'wine': 0, 'silver': 0, 'kept': 0}

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            v = mx / 255
            s = 0.0 if mx == 0 else (mx - mn) / mx

            # الأسودُ حول العمل يُترك: هو أرضيةُ الصورة لا أرضيةُ الأيقونة،
            # و`make_icons.py` يقصّه.
            if v < 0.12:
                moved['kept'] += 1
                continue

            # درجةُ اللون — تُحسب فقط عند الحاجة إليها.
            if mx == mn:
                hue = 0.0
            elif mx == r:
                hue = (60 * (((g - b) / (mx - mn)) % 6)) % 360
            elif mx == g:
                hue = 60 * (((b - r) / (mx - mn)) + 2)
            else:
                hue = 60 * (((r - g) / (mx - mn)) + 4)

            if s >= 0.20 and 170 <= hue <= 265:
                # ــ الأزرق ــ  (المرابطُ مقيسةٌ أعلاه)
                px[x, y] = ramp(WINE, blue_position(v, lo, mid, hi)) + (a,)
                moved['wine'] += 1
            elif s < 0.20:
                # ــ الفضّيّ والأبيض ــ
                #
                # وحدُّه ٠٫٢٠ نفسُه الذي قِيس في التوزيع: النصُّ والقلبُ
                # دونه، والذهبُ فوقه — ولمعاتُ الذهب البيضاءُ تقع هنا فتصير
                # ذهباً فاتحاً، وهو ما كانت تُحاكيه أصلاً.
                px[x, y] = ramp(GOLD, (v - 0.12) / 0.88) + (a,)
                moved['silver'] += 1
            else:
                # الذهبُ يبقى كما هو — هو لونُ الهويّة أصلاً.
                moved['kept'] += 1

    wiped = blank_stray_islands(im)
    print(f'طُمست كتلٌ دخيلة: {wiped:,} بكسل (شارةُ المولّد ونحوُها)')

    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    total = sum(moved.values())
    print(f'أزرقُ ← نبيذيّ: {moved["wine"]:,} بكسل ({moved["wine"]*100//total}٪)')
    print(f'فضّيٌّ ← ذهب:   {moved["silver"]:,} بكسل ({moved["silver"]*100//total}٪)')
    print(f'بقي كما هو:     {moved["kept"]:,} بكسل ({moved["kept"]*100//total}٪)')
    print(f'\n✓ {dst}')


if __name__ == '__main__':
    main()
