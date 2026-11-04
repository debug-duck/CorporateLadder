"""Magenta chroma-key helpers for Layer sprite sheets (generated on flat #FF00FF)."""
import numpy as np
from PIL import Image
from scipy import ndimage

BG = np.array([250.0, 0.0, 250.0])


def key_magenta(img: Image.Image) -> Image.Image:
    """RGBA with the magenta background removed and edge pixels un-mixed from it."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip(np.minimum(r, b) - g, 0, None)          # "magenta-ness"
    hi, lo = 150.0, 35.0
    alpha = np.clip((hi - m) / (hi - lo), 0.0, 1.0)
    safe = np.maximum(alpha, 0.05)[..., None]
    fg = np.clip((a - (1.0 - alpha)[..., None] * BG) / safe, 0, 255)
    out = np.dstack([fg, alpha * 255.0]).astype(np.uint8)
    out[alpha < 0.04] = 0
    return Image.fromarray(out, "RGBA")


def components(rgba: Image.Image, dilate=8, min_area=600):
    """Connected alpha components (dilated so nearby fragments merge): [(bbox, crop)], reading order."""
    arr = np.asarray(rgba)
    mask = arr[..., 3] > 24
    grown = ndimage.binary_dilation(mask, iterations=dilate)
    lab, _ = ndimage.label(grown)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None:
            continue
        region = (lab[sl] == i) & mask[sl]
        if region.sum() < min_area:
            continue
        crop = arr[sl].copy()
        crop[~ndimage.binary_dilation(region, iterations=2)] = 0
        out.append(((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop), Image.fromarray(crop, "RGBA")))
    return out


def reading_order(comps, row_tol=120):
    """Sort components top-to-bottom in rows, then left-to-right."""
    comps = sorted(comps, key=lambda c: (c[0][1] + c[0][3]) / 2)
    rows, cur, cy = [], [], None
    for c in comps:
        y = (c[0][1] + c[0][3]) / 2
        if cy is not None and abs(y - cy) > row_tol:
            rows.append(cur); cur = []
        cur.append(c); cy = y if not cur[:-1] else cy
    if cur:
        rows.append(cur)
    return [c for r in rows for c in sorted(r, key=lambda c: c[0][0])]


def clean_small(rgba: Image.Image, keep_ratio=0.02) -> Image.Image:
    """Drop specks smaller than keep_ratio of the biggest blob (stray magenta-edge noise)."""
    arr = np.asarray(rgba).copy()
    mask = arr[..., 3] > 24
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=3))
    if n <= 1:
        return rgba
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * keep_ratio])
    arr[~keep] = 0
    return Image.fromarray(arr, "RGBA")


def trim(rgba: Image.Image, pad=4) -> Image.Image:
    bb = rgba.getbbox()
    if not bb:
        return rgba
    l, t, r, b = bb
    return rgba.crop((max(0, l - pad), max(0, t - pad), min(rgba.width, r + pad), min(rgba.height, b + pad)))


def fit(rgba: Image.Image, max_w: int, max_h: int) -> Image.Image:
    s = min(max_w / rgba.width, max_h / rgba.height, 1.0)
    if s >= 1.0:
        return rgba
    return rgba.resize((max(1, round(rgba.width * s)), max(1, round(rgba.height * s))), Image.LANCZOS)
