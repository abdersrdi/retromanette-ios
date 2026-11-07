"""Turns the raw simulator screenshots into App Store sets, in English, French and Arabic.

  python tools/frame_store.py <folder with iphone/ and ipad/> <output folder>

Output (not committed):
  <out>/plain/<device>/<lang>/NN-name.png        the screenshots as they are, in the order of the listing
  <out>/framed/iphone-1320x2868/<lang>/...       a dark gradient and a caption above the screenshot
  <out>/framed/iphone-1206x2622/, iphone-1179x2556/   the same resized
  <out>/framed/ipad-2064x2752/<lang>/...
  <out>/framed/foldable-2007x2853/, foldable-1398x2034/   built from the iPad screenshots
  <out>/iap/review-premium-1320x2868.png         the Premium page, for the subscription's review screenshot
"""
import os
import shutil
import sys

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAW, OUT = sys.argv[1], sys.argv[2]
FONT = r"C:\Windows\Fonts\segoeuib.ttf"          # has Latin and Arabic glyphs
TOP, BOTTOM = (58, 38, 8), (7, 7, 10)
GLOW = (255, 176, 32)

# (raw file name, caption per language) in the order of the listing
ORDER = [
    ("01-discover", {"en": "Open-source retro games", "fr": "Des jeux rétro libres", "ar": "ألعاب كلاسيكية مفتوحة المصدر"}),
    ("03-play", {"en": "Play with touch or a controller", "fr": "Jouez au tactile ou à la manette", "ar": "العب باللمس أو بذراع التحكم"}),
    ("04-play-gba", {"en": "Handheld classics on your iPhone", "fr": "Des classiques portables sur iPhone", "ar": "ألعاب محمولة كلاسيكية على iPhone"}),
    ("02-game", {"en": "Every license shown, every source linked", "fr": "Chaque licence et chaque source affichées", "ar": "كل رخصة معروضة وكل مصدر مرتبط"}),
    ("05-library", {"en": "Add your own game files", "fr": "Ajoutez vos propres jeux", "ar": "أضف ملفات ألعابك"}),
    ("06-premium", {"en": "No ads and 9 save slots", "fr": "Sans pub, 9 sauvegardes par jeu", "ar": "بلا إعلانات و9 خانات حفظ"}),
    ("07-settings", {"en": "English, French and Arabic", "fr": "Français, anglais et arabe", "ar": "العربية والإنجليزية والفرنسية"}),
]
LANGS = ["en", "ar", "fr"]


def shape(text, lang):
    return get_display(arabic_reshaper.reshape(text)) if lang == "ar" else text


def wrap(draw, text, font, max_width, lang):
    lines, current = [], ""
    for word in text.split():
        trial = (current + " " + word).strip()
        if draw.textlength(shape(trial, lang), font=font) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def background(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * min(1, t * 1.6)) for i in range(3))
        for x in range(w):
            px[x, y] = c
    glow = Image.new("RGBA", (w, h), GLOW + (0,))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((w * 0.1, -h * 0.12, w * 0.9, h * 0.22), fill=70)
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(w // 6)))
    return Image.alpha_composite(img.convert("RGBA"), glow)


def make(src, dst, w, h, shot_w, shot_y, font_size, caption, lang):
    canvas = background(w, h)
    shot = Image.open(src).convert("RGBA")
    shot_h = int(shot.height * shot_w / shot.width)
    shot = shot.resize((shot_w, shot_h), Image.LANCZOS)
    radius = int(shot_w * 0.07)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.size[0] - 1, shot.size[1] - 1), radius, fill=255)
    x = (w - shot_w) // 2
    shadow_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shadow_mask).rounded_rectangle((x, shot_y + 25, x + shot_w, shot_y + shot_h + 25), radius, fill=130)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(35)))
    canvas.alpha_composite(shadow)
    canvas.paste(shot, (x, shot_y), mask)
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT, font_size)
    lines = wrap(draw, caption, font, int(w * 0.86), lang)
    line_h = int(font_size * 1.2)
    y = (shot_y - line_h * len(lines)) // 2
    for line in lines:
        text = shape(line, lang)
        draw.text(((w - draw.textlength(text, font=font)) / 2, y), text, font=font, fill=(244, 241, 234, 255))
        y += line_h
    canvas.convert("RGB").save(dst, "PNG", optimize=True)


def main():
    for sub in ("plain", "framed", "iap"):
        shutil.rmtree(os.path.join(OUT, sub), ignore_errors=True)
    os.makedirs(os.path.join(OUT, "iap"), exist_ok=True)

    for lang in LANGS:
        for device in ("iphone", "ipad"):
            os.makedirs(f"{OUT}/plain/{device}/{lang}", exist_ok=True)
        for folder in ("iphone-1320x2868", "iphone-1206x2622", "iphone-1179x2556", "ipad-2064x2752", "foldable-2007x2853", "foldable-1398x2034"):
            os.makedirs(f"{OUT}/framed/{folder}/{lang}", exist_ok=True)

        for index, (name, captions) in enumerate(ORDER, 1):
            caption = captions[lang]
            label = f"{index:02d}-{name.split('-', 1)[1]}"
            phone = f"{RAW}/iphone/{lang}/{name}.png"
            pad = f"{RAW}/ipad/{lang}/{name}.png"
            shutil.copy(phone, f"{OUT}/plain/iphone/{lang}/{label}.png")
            shutil.copy(pad, f"{OUT}/plain/ipad/{lang}/{label}.png")

            make(phone, f"{OUT}/framed/iphone-1320x2868/{lang}/{label}.png", 1320, 2868, 1100, 520, 108, caption, lang)
            for folder, (w, h) in {"iphone-1206x2622": (1206, 2622), "iphone-1179x2556": (1179, 2556)}.items():
                Image.open(f"{OUT}/framed/iphone-1320x2868/{lang}/{label}.png").convert("RGB").resize((w, h), Image.LANCZOS).save(
                    f"{OUT}/framed/{folder}/{lang}/{label}.png", "PNG", optimize=True)
            make(pad, f"{OUT}/framed/ipad-2064x2752/{lang}/{label}.png", 2064, 2752, 1650, 440, 124, caption, lang)
            make(pad, f"{OUT}/framed/foldable-2007x2853/{lang}/{label}.png", 2007, 2853, 1560, 480, 120, caption, lang)
            make(pad, f"{OUT}/framed/foldable-1398x2034/{lang}/{label}.png", 1398, 2034, 1090, 350, 88, caption, lang)

    premium = f"{RAW}/iphone/en/06-premium.png"
    Image.open(premium).convert("RGB").save(f"{OUT}/iap/review-premium-1320x2868.png", "PNG", optimize=True)
    print("done", OUT)


main()
