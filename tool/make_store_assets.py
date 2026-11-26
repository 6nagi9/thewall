#!/usr/bin/env python3
"""Builds Known's store listing graphics from real app captures.

    flutter test tool/screenshots/store_test.dart
    python3 -I tool/make_store_assets.py

Inputs:  build/screens/store/NN-name.png (1290x2796, the real screens rendered
         with demo data by the harness).
Outputs:
  store/appstore/icon-1024.png            1024x1024, no alpha
  store/appstore/iphone-6.9/NN-name.png   1320x2868
  store/play/images/icon.png              512x512
  store/play/images/featureGraphic.png    1024x500
  store/play/images/phoneScreenshots/NN-name.png  1080x1920
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAPTURES = os.path.join(ROOT, "build", "screens", "store")
FONTS = os.path.join(ROOT, "assets", "fonts")

BG = (19, 16, 13)        # ink950
TEXT = (250, 245, 236)   # paper
DIM = (181, 169, 155)    # ink300
LINE = (56, 48, 42)      # ink700
CLAY = (224, 122, 95)

# Every claim is true of the build.
SHOTS = [
    ("01-wall", "See how people", "really see you", "Structured feedback from people who know you"),
    ("02-feedback", "You decide", "what goes public", "Every brick stays private until you show it"),
    ("03-give", "Lay a brick for", "someone you know", "Ratings and curated tags, not rants"),
    ("04-trends", "Watch yourself", "grow", "Trends and an AI summary with Premium"),
    ("05-badges", "Streaks and badges", "for showing up", "Give thoughtful feedback, grow your collection"),
]


def head_font(size):
    return ImageFont.truetype(os.path.join(FONTS, "BricolageGrotesque-800.ttf"), size)


def body_font(size):
    return ImageFont.truetype(os.path.join(FONTS, "SchibstedGrotesk-600.ttf"), size)


def glow_background(w, h, cy):
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = int(w * 0.55)
    ImageDraw.Draw(glow).ellipse([w // 2 - r, cy - r, w // 2 + r, cy + r], fill=CLAY + (40,))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.16))
    img.paste(glow, (0, 0), glow)
    return img


def rounded(img, radius, border=0):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    if border:
        ImageDraw.Draw(out).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius, outline=LINE, width=border)
    return out


def compose(capture, w, h, plain, accent, sub, scale):
    top = int(h * 0.05)
    phone_w = int(w * scale)
    phone_h = int(capture.size[1] * phone_w / capture.size[0])
    img = glow_background(w, h, cy=int(h * 0.62))
    d = ImageDraw.Draw(img)
    size = int(w * 0.08)
    while size > 20 and max(d.textlength(plain, font=head_font(size)), d.textlength(accent, font=head_font(size))) > w * 0.86:
        size -= 2
    head = head_font(size)
    for text, colour in ((plain, TEXT), (accent, CLAY)):
        d.text(((w - d.textlength(text, font=head)) / 2, top), text, font=head, fill=colour)
        top += int(size * 1.12)
    small = body_font(int(w * 0.034))
    while d.textlength(sub, font=small) > w * 0.9:
        small = body_font(small.size - 2)
    d.text(((w - d.textlength(sub, font=small)) / 2, top + int(w * 0.015)), sub, font=small, fill=DIM)
    phone_top = top + int(w * 0.015) + small.size + int(h * 0.03)
    screen = capture.resize((phone_w, phone_h), Image.LANCZOS)
    framed = rounded(screen, int(phone_w * 0.07), border=max(3, w // 330))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(w - phone_w) // 2, phone_top + 20, (w + phone_w) // 2, phone_top + phone_h + 20], int(phone_w * 0.07), fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(w * 0.03))
    img.paste(shadow, (0, 0), shadow)
    img.paste(framed, ((w - phone_w) // 2, phone_top), framed)
    return img.convert("RGB")


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print(f"wrote {rel} {img.size[0]}x{img.size[1]}")


def icon():
    return Image.open(os.path.join(ROOT, "assets", "icon", "icon.png")).convert("RGBA")


def feature_graphic():
    w, h = 1024, 500
    img = glow_background(w, h, cy=h // 2)
    mark = rounded(icon().resize((220, 220), Image.LANCZOS).convert("RGB"), 48)
    img.paste(mark, (110, (h - 220) // 2), mark)
    d = ImageDraw.Draw(img)
    d.text((380, 140), "Known", font=head_font(120), fill=TEXT)
    d.text((386, 290), "Honest feedback,", font=body_font(40), fill=DIM)
    d.text((386, 340), "on your terms.", font=body_font(40), fill=CLAY)
    return img


def main():
    ic = icon()
    flat = Image.new("RGB", ic.size, BG)
    flat.paste(ic, (0, 0), ic)
    save(flat.resize((1024, 1024), Image.LANCZOS), "store/appstore/icon-1024.png")
    save(ic.resize((512, 512), Image.LANCZOS), "store/play/images/icon.png")
    save(feature_graphic(), "store/play/images/featureGraphic.png")
    for stem, plain, accent, sub in SHOTS:
        cap = Image.open(os.path.join(CAPTURES, f"{stem}.png")).convert("RGB")
        save(compose(cap, 1320, 2868, plain, accent, sub, 0.80), f"store/appstore/iphone-6.9/{stem}.png")
        save(compose(cap, 1080, 1920, plain, accent, sub, 0.66), f"store/play/images/phoneScreenshots/{stem}.png")


if __name__ == "__main__":
    main()
