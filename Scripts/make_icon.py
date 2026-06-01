from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources" / "AppIcon.iconset"
MASTER = ROOT / "Resources" / "AppIcon-1024.png"
ICNS = ROOT / "Resources" / "AppIcon.icns"


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(size):
            pixels[x, y] = color
    return image.convert("RGBA")


def draw_icon(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (74, 82, size - 74, size - 54),
        radius=220,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    image.alpha_composite(shadow)

    base = gradient(size, (16, 180, 152), (20, 88, 180))
    base_mask = rounded_mask(size, 210)
    image.alpha_composite(Image.composite(base, Image.new("RGBA", (size, size)), base_mask))

    inner = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner_draw = ImageDraw.Draw(inner)
    inner_draw.rounded_rectangle(
        (86, 76, size - 86, size - 96),
        radius=176,
        outline=(255, 255, 255, 80),
        width=8,
    )
    inner_draw.rounded_rectangle(
        (118, 110, size - 118, size - 126),
        radius=146,
        outline=(255, 255, 255, 42),
        width=4,
    )
    image.alpha_composite(inner)

    # Chat bubble body.
    bubble = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bubble_draw = ImageDraw.Draw(bubble)
    bubble_draw.rounded_rectangle((180, 198, 844, 614), radius=132, fill=(255, 255, 255, 232))
    bubble_draw.polygon([(344, 590), (266, 742), (478, 616)], fill=(255, 255, 255, 232))
    bubble_draw.rounded_rectangle((206, 224, 818, 586), radius=112, outline=(255, 255, 255, 245), width=10)
    image.alpha_composite(bubble)

    # Document card.
    card = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle((300, 432, 752, 824), radius=62, fill=(245, 250, 255, 244))
    card_draw.rounded_rectangle((300, 432, 752, 824), radius=62, outline=(6, 92, 140, 44), width=7)
    for index, y in enumerate((542, 612, 682, 752)):
        width = 320 if index < 3 else 236
        card_draw.rounded_rectangle((372, y, 372 + width, y + 22), radius=11, fill=(36, 104, 143, 84))
    image.alpha_composite(card)

    # Audio waveform.
    wave = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wave_draw = ImageDraw.Draw(wave)
    bars = [
        (406, 338, 68),
        (468, 304, 136),
        (530, 270, 204),
        (592, 310, 124),
        (654, 350, 46),
    ]
    for x, center_y, height in bars:
        wave_draw.rounded_rectangle(
            (x, center_y - height // 2, x + 28, center_y + height // 2),
            radius=14,
            fill=(10, 134, 180, 220),
        )
    wave_draw.arc((340, 248, 720, 462), start=188, end=352, fill=(10, 134, 180, 78), width=14)
    image.alpha_composite(wave)

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.ellipse((156, 124, 720, 560), fill=(255, 255, 255, 28))
    highlight = highlight.filter(ImageFilter.GaussianBlur(16))
    image.alpha_composite(highlight)

    return image


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    master = draw_icon()
    master.save(MASTER)

    specs = [
        (16, 1),
        (16, 2),
        (32, 1),
        (32, 2),
        (128, 1),
        (128, 2),
        (256, 1),
        (256, 2),
        (512, 1),
        (512, 2),
    ]
    for points, scale in specs:
        pixels = points * scale
        name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
        master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICONSET / name)

    master.save(
        ICNS,
        sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)],
    )


if __name__ == "__main__":
    main()
