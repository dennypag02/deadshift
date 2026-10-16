"""Deterministic fit and explicit texture seam stages. No generation or promotion."""
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


def dimensions(target):
    if set(target) == {'long_side'}:
        return (target['long_side'], target['long_side'])  # Exact transparent canvas.
    return (target['width'], target['height'])


def fit(image, size, *, trim=True, mode='pad', background=(0, 0, 0, 0)):
    if mode not in ('pad', 'crop') or min(size) < 1:
        raise ValueError('Invalid fit rule or dimensions')
    image = image.convert('RGBA')
    if trim:
        bbox = image.getchannel('A').getbbox()
        if not bbox:
            raise ValueError('Empty alpha channel')
        image = image.crop(bbox)
    if mode == 'crop':
        return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)
    ratio = min(size[0] / image.width, size[1] / image.height)
    resized = image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))),
                           Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', size, background)
    canvas.alpha_composite(resized, ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2))
    return canvas


def prepare_inpaint(image, band=64):
    image = image.convert('RGB')
    shifted = ImageChops.offset(image, image.width // 2, image.height // 2)
    mask = Image.new('L', image.size, 0)
    draw = ImageDraw.Draw(mask)
    x, y = image.width // 2, image.height // 2
    draw.rectangle((x-band, 0, x+band, image.height), fill=255)
    draw.rectangle((0, y-band, image.width, y+band), fill=255)
    shifted = shifted.convert('RGBA')
    # Comfy LoadImage: mask = 1 - alpha.
    shifted.putalpha(ImageChops.invert(mask))
    return shifted


def periodic_edges(image, band=12):
    """C0 wrap continuity; human 3x3 review must still judge visible repetition."""
    output = image.convert('RGB').copy()
    pixels = output.load()
    w, h = output.size
    for k in range(min(band, w // 2)):
        weight = (1 - k / band) * 0.5
        for y in range(h):
            a, b = pixels[k, y], pixels[w-1-k, y]
            pixels[k, y] = tuple(round(v * (1-weight) + u * weight) for v, u in zip(a, b))
            pixels[w-1-k, y] = tuple(round(u * (1-weight) + v * weight) for v, u in zip(a, b))
    for k in range(min(band, h // 2)):
        weight = (1 - k / band) * 0.5
        for x in range(w):
            a, b = pixels[x, k], pixels[x, h-1-k]
            pixels[x, k] = tuple(round(v * (1-weight) + u * weight) for v, u in zip(a, b))
            pixels[x, h-1-k] = tuple(round(u * (1-weight) + v * weight) for v, u in zip(a, b))
    return output


def grid3(image):
    canvas = Image.new(image.mode, (image.width * 3, image.height * 3))
    for x in range(3):
        for y in range(3):
            canvas.paste(image, (x * image.width, y * image.height))
    return canvas


def validate_wrap(image):
    w, h = image.size
    horizontal = ImageChops.difference(image.crop((0,0,1,h)), image.crop((w-1,0,w,h)))
    vertical = ImageChops.difference(image.crop((0,0,w,1)), image.crop((0,h-1,w,h)))
    if horizontal.getbbox() or vertical.getbbox():
        raise ValueError('Opposite texture edges differ')
