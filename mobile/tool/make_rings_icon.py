#!/usr/bin/env python3
"""يُخرج أيقونةَ التطبيق من صورة الخواتم والجنبيّة.

    python3 tool/make_rings_icon.py                    # يكتب assets/brand/app_icon.png
    python3 tool/make_rings_icon.py --out /tmp/x.png   # للمعاينة بلا مساس

ثمّ:  python3 tool/make_icons.py assets/brand/app_icon.png

── لماذا سكربتٌ لا صورةٌ تُلصق ─────────────────────────────────────────────

الأصلُ `rings_ai.webp` يبقى كما وصل، وهذا الملفُّ يُخرج منه الأيقونة. فما
وقع للصورة **مكتوبٌ يُقرأ ويُعاد**: إن بُدّلت الأرضيّةُ من بيضاءَ إلى نبيذيّة
بُدّل رقمٌ واحدٌ هنا وأُعيد التشغيل. وصورةٌ تُلصق لا يعرف أحدٌ بعد شهرٍ كيف
صُنعت ولا كيف تُصنع مثلُها — وهذا عينُ ما وقع مع أيقونة آيفون من قبل، بقيت
شعارَ Flutter شهوراً ولا شيءَ في المستودع ينبّه.

── ثلاثةٌ تُنزع من الصورة ─────────────────────────────────────────────────

**١) شارةُ «Made with AI».** في الزاوية العليا، وتُقاس لا تُخمَّن: يُمسح
الشريطُ العلويُّ ممّا هو أقتمُ من الورق، فتُعرف حدودُها من الصورة نفسِها.
ولو كُتبت الحدودُ رقماً لَبطلت مع أوّل صورةٍ يتبدّل قياسُها.

**٢) القرصُ الأبيضُ حولها.** يُعزل الذهبُ بقناعٍ من **التشبّع أو القتامة**:
القرصُ رماديٌّ فاتحٌ لا مشبَّعٌ ولا قاتم فيسقط، والذهبُ مشبَّعٌ فيبقى،
وحوافُّ الماس قاتمةٌ غيرُ مشبّعةٍ فتبقى بالقتامة. ولو قيل «ما ليس أبيضَ فهو
عمل» لَبقي القرصُ كلُّه.

**٣) الانعكاسُ المرآتيُّ تحت الخواتم.** يُقطع عند أوّل فجوةٍ بلا لونٍ مشبَّع
بعد منتصف العمل. وعلى أرضيّةٍ داكنةٍ يُقرأ لطخةً رماديّةً تحت الذهب — رأيتُها
في أوّل معاينة.

── ولمَ ٦٢٪ من الضلع ──────────────────────────────────────────────────────

أيقونةُ أندرويد المتكيّفة طبقةٌ ١٠٨، ولا يضمن النظامُ إظهارَ غير ٧٢ منها —
أي ثلثيها. فما تجاوز ذلك يقصّه قناعُ الجهاز: دائرةً في جوالٍ ومربّعاً مستديراً
في آخر. وبِـ٦٢٪ يبقى طرفُ الجنبيّة وحافّةُ الخاتم داخل القناعين جميعاً؛
قِستُهما في المعاينة.
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageFilter
except ImportError:
    sys.exit('يلزم Pillow:  pip install Pillow')

HERE = Path(__file__).resolve().parent.parent
SRC = HERE / 'assets/brand/rings_ai.webp'
DST = HERE / 'assets/brand/app_icon.png'

SIDE = 1024
ART_SHARE = 0.62
PAPER = (0xFF, 0xFF, 0xFF)          # أرضيّةُ الأيقونة


def sat_lum(p):
    r, g, b = p[:3]
    return max(r, g, b) - min(r, g, b), (r * 299 + g * 587 + b * 114) // 1000


def wipe_badge(im: Image.Image) -> Image.Image:
    """يمسح شارةَ المولّد من الشريط العلويّ — بحدودٍ مقيسةٍ من الصورة."""
    w, h = im.size
    px = im.load()
    band = int(h * 0.12)
    xs, ys = [], []
    for y in range(band):
        for x in range(w):
            if sat_lum(px[x, y])[1] < 215:
                xs.append(x)
                ys.append(y)
    if not xs:
        print('  · لا شارةَ في الشريط العلويّ')
        return im
    pad = int(w * 0.01)
    box = (max(0, min(xs) - pad), max(0, min(ys) - pad),
           min(w, max(xs) + pad + 1), min(band, max(ys) + pad + 1))
    print(f'  · الشارة مُسحت: {box}')
    im.paste(Image.new('RGB', (box[2] - box[0], box[3] - box[1]), (250, 250, 250)), box)
    return im


def cut_art(im: Image.Image) -> Image.Image:
    """يعزل العملَ عن الورق ويقصّ إلى حدّه."""
    w, h = im.size
    px = im.load()
    mask = Image.new('L', (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            s, l = sat_lum(px[x, y])
            mp[x, y] = 255 if (s > 26 or l < 190) else 0
    # يُغلق ثقبٌ داخل العمل ثمّ تُلطَّف الحافّة — وإلّا خرجت مسنّنة.
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))
    box = mask.getbbox()
    if box is None:
        sys.exit('لم يُعثر على عملٍ في الصورة — القناعُ فارغ')
    print(f'  · حدُّ العمل: {box}')
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    out.paste(im, mask=mask)
    return out.crop(box)


def drop_reflection(art: Image.Image) -> Image.Image:
    """يقطع الانعكاسَ المرآتيَّ تحت العمل — عند أوّل فجوةٍ بلا لونٍ مشبَّع."""
    w, h = art.size
    px = art.load()
    rows = []
    for y in range(h):
        n = 0
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 150 and max(r, g, b) - min(r, g, b) > 70:
                n += 1
        rows.append(n)

    gap, start = 0, None
    for y in range(h // 2, h):
        if rows[y]:
            gap = 0
            continue
        gap += 1
        if gap == 1:
            start = y
        # ثمانيةُ صفوفٍ خاليةٍ فجوةٌ حقيقيّة، وما دونها ثقبٌ داخل الجسم.
        if gap >= 8:
            print(f'  · الانعكاس قُطع عند {start}')
            cut = art.crop((0, 0, w, start))
            return cut.crop(cut.getbbox())
    print('  · لا انعكاسَ يُقطع')
    return art


def compose(art: Image.Image) -> Image.Image:
    canvas = Image.new('RGBA', (SIDE, SIDE), PAPER + (255,))
    w, h = art.size
    k = (SIDE * ART_SHARE) / max(w, h)
    small = art.resize((round(w * k), round(h * k)), Image.LANCZOS)
    canvas.alpha_composite(small, ((SIDE - small.width) // 2, (SIDE - small.height) // 2))
    return canvas.convert('RGB')


def main() -> None:
    out = DST
    args = sys.argv[1:]
    if '--out' in args:
        i = args.index('--out')
        out = Path(args[i + 1])
    if not SRC.exists():
        sys.exit(f'لا ملف: {SRC}')
    print(f'الأصل: {SRC.name}')
    art = drop_reflection(cut_art(wipe_badge(Image.open(SRC).convert('RGB'))))
    print(f'  · العمل بعد التنظيف: {art.size}')
    compose(art).save(out)
    print(f'كُتب {out}  ({SIDE}×{SIDE}، العمل {round(ART_SHARE * 100)}٪ من الضلع)')


if __name__ == '__main__':
    main()
