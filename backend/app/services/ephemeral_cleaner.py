import os
import time
from pathlib import Path

TEMP_UPLOAD_DIR = Path(os.getenv("TEMP_UPLOAD_DIR", "/app/temp_uploads"))
MAX_FILE_AGE_SECONDS = 300  # 5 minutes maximum lifetime for local chunks

def purge_ephemeral_container_cache():
    """
    Cleans local temporary media chunks to avoid container bloat and comply with DPDP data minimization.
    """
    if not TEMP_UPLOAD_DIR.exists():
        return

    now = time.time()
    purged_count = 0

    for file_path in TEMP_UPLOAD_DIR.glob("*"):
        if file_path.is_file():
            try:
                file_age = now - file_path.stat().st_mtime
                if file_age > MAX_FILE_AGE_SECONDS:
                    file_path.unlink(missing_ok=True)
                    purged_count += 1
            except Exception as e:
                print(f"⚠️ [Cache Cleaner] Error deleting {file_path}: {e}")

    if purged_count > 0:
        print(f"🧹 [Cache Cleaner] Purged {purged_count} ephemeral files from container storage.")
