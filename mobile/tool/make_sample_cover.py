# صورةٌ مركَّبةٌ للتوضيح وحدَها — لا صورةٌ حقيقيّةٌ ولا مأخوذةٌ من الشبكة.
# غرضُها أن يُرى في المقترح ما يفعله غلافٌ فوتوغرافيّ بالرأس.
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 1200, 480
random.seed(7)

img = Image.new('RGB', (W, H), (26, 14, 20))
d = ImageDraw.Draw(img)

# تدرّجٌ ليليّ دافئ
for y in range(H):
    t = y / H
    r = int(38 + 50 * (1 - t))
    g = int(18 + 22 * (1 - t))
    b = int(28 + 26 * (1 - t))
    d.line([(0, y), (W, y)], fill=(r, g, b))

# ستائرُ خلفيّة
for i in range(14):
    x = i * (W / 13)
    w = 26 + 10 * math.sin(i)
    d.polygon([(x - w, 0), (x + w, 0), (x + w * 0.6, H), (x - w * 0.6, H)],
              fill=(58 + (i % 3) * 6, 26, 38))
img = img.filter(ImageFilter.GaussianBlur(18))

# أنوارٌ معلّقة — بوكيه
glow = Image.new('RGB', (W, H), (0, 0, 0))
gd = ImageDraw.Draw(glow)
for _ in range(120):
    x = random.uniform(0, W)
    y = random.uniform(0, H * 0.78)
    r = random.uniform(5, 26)
    a = random.uniform(0.25, 1.0)
    c = (int(255 * a), int(214 * a), int(150 * a))
    gd.ellipse([x - r, y - r, x + r, y + r], fill=c)
glow = glow.filter(ImageFilter.GaussianBlur(9))
img = Image.blend(img, Image.new('RGB', (W, H), (0, 0, 0)), 0.0)
img = Image.composite(Image.new('RGB', (W, H), (255, 240, 210)), img,
                      glow.convert('L').point(lambda v: min(255, int(v * 1.4))))

# طاولةٌ في المقدّمة
fg = Image.new('RGB', (W, H), (0, 0, 0))
fd = ImageDraw.Draw(fg)
fd.rectangle([0, int(H * 0.74), W, H], fill=(70, 30, 44))
for i in range(9):
    x = 60 + i * 135
    fd.ellipse([x, int(H * 0.70), x + 74, int(H * 0.70) + 44], fill=(196, 150, 96))
fg = fg.filter(ImageFilter.GaussianBlur(14))
img = Image.blend(img, fg, 0.45)

out = sys.argv[1] if len(sys.argv) > 1 else 'sample_cover.png'
img.filter(ImageFilter.GaussianBlur(0.6)).save(out)
print('ok', out, img.size)
