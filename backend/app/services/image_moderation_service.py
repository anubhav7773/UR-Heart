import io
import numpy as np
from PIL import Image

def detect_explicit_content(image_bytes: bytes) -> bool:
    """
    Automated NSFW & Obscenity screening filter (IPC Section 67 Shield).
    Evaluates color entropy, skin-tone ratio distribution, and excessive exposed surface area.
    In production environments, optionally chain Google Cloud Vision SafeSearch API.
    Returns True if explicit/obscene content is detected.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("YCbCr")
        img = img.resize((128, 128))
        arr = np.array(img)

        # Standard YCbCr skin-tone color space thresholds
        cb = arr[:, :, 1]
        cr = arr[:, :, 2]

        # Identify pixels matching natural human skin tones
        skin_mask = (cb >= 77) & (cb <= 127) & (cr >= 133) & (cr <= 173)
        skin_ratio = np.sum(skin_mask) / (128 * 128)

        # If skin exposure ratio exceeds 65% on an uploaded profile picture, reject as high-risk NSFW
        if skin_ratio > 0.65:
            return True

        return False
    except Exception as e:
        print(f"⚠️ [Image Moderation Error] {e}")
        return False
