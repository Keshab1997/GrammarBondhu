#!/usr/bin/env python3
"""Author talking + blinking frames for Mrs. Sen's three lesson poses.

`teacher_pointer`, `teacher_book` and `teacher_invite` are standees drawn from
other camera angles, so a mouth retargeted from `teacher_full` leaves a cheek
seam. Instead each pose gets its own deterministic mouth animation:

  * a local, smoothly-feathered jaw opening (lower lip travels down, upper lip
    lifts a couple of pixels) — pure geometry, so every pore, blush and cheek
    contour of the original art survives untouched;
  * a soft mouth cavity with a highlight along the upper teeth, so an open
    vowel reads as speech rather than a stretched smile;
  * eyelid frames lifted from `teacher_blink` through the measured eye-band
    alignment, because lids are flat interior detail with no shading seam.

Run: python3 tool/build_teacher_pose_frames.py
"""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "assets" / "characters"

# Measured on the shipped sprites: pupil centres and the mouth's centre line.
FACES: dict[str, dict[str, tuple[float, float]]] = {
    "teacher_full": {
        "left_pupil": (113, 80),
        "right_pupil": (150, 80),
        "mouth": (130, 128),
    },
    "teacher_pointer": {
        "left_pupil": (328, 84),
        "right_pupil": (363, 84),
        "mouth": (356, 118),
    },
    "teacher_book": {
        "left_pupil": (252, 80),
        "right_pupil": (287, 80),
        "mouth": (264, 117),
    },
    "teacher_invite": {
        "left_pupil": (150, 80),
        "right_pupil": (196, 80),
        "mouth": (172, 116),
    },
}

POSES = ("teacher_pointer", "teacher_book", "teacher_invite")

EYE_RECT = (90, 56, 182, 104)  # brow + lens + lid inside teacher_full


def load(name: str) -> np.ndarray:
    return np.array(Image.open(ROOT / f"{name}.webp").convert("RGBA"))


def similarity(pose: str) -> tuple[np.ndarray, float]:
    """Scale/rotate/translate from teacher_full pixels to [pose] pixels."""
    a = FACES["teacher_full"]
    b = FACES[pose]
    v1 = np.array(b["right_pupil"]) - np.array(b["left_pupil"])
    v2 = np.array(a["right_pupil"]) - np.array(a["left_pupil"])
    scale = float(np.linalg.norm(v1) / np.linalg.norm(v2))
    angle = float(np.arctan2(v1[1], v1[0]) - np.arctan2(v2[1], v2[0]))
    cos, sin = np.cos(angle) * scale, np.sin(angle) * scale
    rot = np.array([[cos, -sin], [sin, cos]])
    shift = np.array(b["mouth"], float) - rot @ np.array(a["mouth"], float)
    return np.column_stack([rot, shift]), scale


def _mouth_frame(pose: str, shape: tuple[int, int]):
    """Local (u, v) mouth coordinates: u along the lip line, v down the jaw."""
    left = np.array(FACES[pose]["left_pupil"], float)
    right = np.array(FACES[pose]["right_pupil"], float)
    cx, cy = FACES[pose]["mouth"]
    angle = float(np.arctan2((right - left)[1], (right - left)[0]))
    h, w = shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u = np.cos(angle) * (xs - cx) + np.sin(angle) * (ys - cy)
    v = -np.sin(angle) * (xs - cx) + np.cos(angle) * (ys - cy)
    return u, v


def open_mouth(base: np.ndarray, pose: str, openness: float) -> np.ndarray:
    """[openness] 0 = closed, 1 = wide open. Pure geometry: the art survives.

    A real jaw hinge does two things at once — the lower lip and chin travel
    down, and the mouth corners narrow a touch. Both are driven here by a
    smooth field that dies out at the nose, cheeks and chin, so the pose's own
    shading, blush and contours stay pixel-identical everywhere else.
    """
    h, w = base.shape[:2]
    u, v = _mouth_frame(pose, (h, w))
    _, scale = similarity(pose)

    half_width = 20.0 * scale
    drop = 11.0 * scale * openness
    lift = 1.2 * scale * openness
    # The jaw follows the lip line but the skin below it lags, which is what
    # keeps the chin from being squashed flat.
    fall = np.clip(
        1.0 - np.sqrt((u / (half_width * 1.5)) ** 2 + (v / (drop * 3.0 + 1e-3)) ** 2),
        0.0,
        1.0,
    ) ** 1.4

    shift = np.where(v >= 0, 0.55 * drop * fall, -lift * fall).astype(np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    warped = cv2.remap(
        base, xs.copy(), ys - shift, cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE
    )

    # The opening itself: an ellipse squeezed into the parting, tapering to the
    # corners so no hard edge appears on the lip.
    lens = np.clip(
        1.0
        - ((u / (half_width * 0.72)) ** 2
           + ((v - 0.18 * drop) / (0.55 * drop + 1e-3)) ** 2),
        0.0,
        1.0,
    )
    lens = cv2.GaussianBlur(lens.astype(np.float32), (0, 0), 0.8 * scale) * openness

    # Mouth interior: warm shadow, never black — this is a friendly classroom.
    interior = np.array([46, 18, 20], np.float32)
    rgb = warped[..., :3].astype(np.float32)
    rgb = rgb * (1 - 0.50 * lens[..., None]) + interior * (0.50 * lens[..., None])

    # Upper incisors: a thin bright arc tucked under the top lip.
    teeth = np.exp(-(((v - 0.02 * drop) / (0.10 * drop + 1e-3)) ** 2)) * lens
    teeth = cv2.GaussianBlur(teeth.astype(np.float32), (0, 0), 0.6 * scale)
    ivory = np.array([240, 231, 220], np.float32)
    rgb = rgb * (1 - 0.80 * teeth[..., None]) + ivory * (0.80 * teeth[..., None])

    # A soft highlight on the rolled lower lip.
    lip = np.exp(-(((v - 0.92 * drop) / (0.16 * drop + 1e-3)) ** 2)) * lens
    rgb = np.clip(rgb * (1 + 0.12 * lip[..., None]), 0, 255)
    return np.dstack([rgb, base[..., 3]]).astype(np.uint8)


def blink_frame(base: np.ndarray, pose: str) -> np.ndarray:
    """Eyelid band from `teacher_blink`, aligned through the pupils."""
    m, scale = similarity(pose)
    h, w = base.shape[:2]
    source = load("teacher_blink")
    warped = cv2.warpAffine(
        source,
        m,
        (w, h),
        flags=cv2.INTER_LANCZOS4,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    ).astype(np.float32)

    quad = np.float32(
        [
            [EYE_RECT[0], EYE_RECT[1]],
            [EYE_RECT[2], EYE_RECT[1]],
            [EYE_RECT[2], EYE_RECT[3]],
            [EYE_RECT[0], EYE_RECT[3]],
        ]
    )
    target = np.round(cv2.transform(quad[:, None, :], m)[:, 0, :]).astype(np.int32)
    mask = np.zeros((h, w), np.float32)
    cv2.fillConvexPoly(mask, target, 1.0, lineType=cv2.LINE_AA)
    mask = cv2.GaussianBlur(mask, (0, 0), 2.2)[..., None]

    out = base.astype(np.float32).copy()
    out[..., :3] = out[..., :3] * (1 - mask) + warped[..., :3] * mask
    out[..., 3] = base[..., 3]
    return np.clip(out, 0, 255).astype(np.uint8)


def band_fraction(pose: str) -> float:
    """Height fraction of the eyelid band inside the drawn sprite."""
    m, _ = similarity(pose)
    top = cv2.transform(np.float32([[[EYE_RECT[0], EYE_RECT[1]]]]), m)[0, 0, 1]
    bottom = cv2.transform(np.float32([[[EYE_RECT[2], EYE_RECT[3]]]]), m)[0, 0, 1]
    height = load(pose).shape[0]
    return float(bottom / height), float(top / height)


def main() -> None:
    for pose in POSES:
        base = load(pose)
        for suffix, openness in (("talk_half", 0.45), ("talk_open", 1.0)):
            frame = open_mouth(base, pose, openness)
            path = ROOT / f"{pose}_{suffix}.webp"
            Image.fromarray(frame).save(path, quality=95, method=6)
            print(f"wrote {path.relative_to(ROOT.parent.parent)}")
        blink = blink_frame(base, pose)
        path = ROOT / f"{pose}_blink.webp"
        Image.fromarray(blink).save(path, quality=95, method=6)
        print(f"wrote {path.relative_to(ROOT.parent.parent)}")
        bottom, _ = band_fraction(pose)
        print(f"  {pose}: eyelid band 0..{bottom:.3f} of sprite height")


if __name__ == "__main__":
    main()
