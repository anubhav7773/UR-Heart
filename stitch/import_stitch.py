import os
import json
import urllib.request
import re

PROJECT_ID = "11309395978596418917"
OUTPUT_DIR = r"c:\Project\UR-Heart\stitch"

# Load saved project info from step 21
project_info_path = r"C:\Users\kshtr\.gemini\antigravity-ide\brain\56cb33f1-62af-437c-8000-0f71ef5c3744\.system_generated\steps\21\output.txt"
with open(project_info_path, "r", encoding="utf-8") as f:
    project_data = json.load(f)

# Load screens list from step 11
screens_path = r"C:\Users\kshtr\.gemini\antigravity-ide\brain\56cb33f1-62af-437c-8000-0f71ef5c3744\.system_generated\steps\11\output.txt"
with open(screens_path, "r", encoding="utf-8") as f:
    screens_data = json.load(f)

os.makedirs(OUTPUT_DIR, exist_ok=True)
screens_dir = os.path.join(OUTPUT_DIR, "screens")
os.makedirs(screens_dir, exist_ok=True)

# 1. Save project metadata
with open(os.path.join(OUTPUT_DIR, "project_info.json"), "w", encoding="utf-8") as f:
    json.dump(project_data, f, indent=2)
print("Saved project_info.json")

# 2. Save designMd
design_theme = project_data.get("designTheme", {})
design_md = design_theme.get("designMd", "")
if design_md:
    with open(os.path.join(OUTPUT_DIR, "design_system.md"), "w", encoding="utf-8") as f:
        f.write(design_md)
    print("Saved design_system.md")

# Mapping helper for screen folder names
def get_folder_name(screen_id, title):
    title_clean = re.sub(r'[^a-zA-Z0-9]+', '_', title).strip('_').lower()
    if screen_id == "0d87e52749864aed90ae5583c3b7e9a6":
        return "00_ur_heart_glowing_logo"
    elif "1_splash" in title_clean:
        return "01_splash_and_age_gate"
    elif "2_photo" in title_clean:
        return "02_photo_upload_and_video_kyc"
    elif "3_discovery" in title_clean:
        return "03_discovery_swipe_feed"
    elif "4_protected" in title_clean:
        return "04_protected_chat_anti_leak"
    elif "5_mutual" in title_clean:
        return "05_mutual_whatsapp_reveal_modal"
    elif "6_profile" in title_clean:
        return "06_profile_streak_vault_erase"
    elif "indian_woman" in title_clean or "close_up_profile" in title_clean:
        return "assets_lucknow_woman_portrait"
    elif "product_requirement" in title_clean or "prd" in title_clean:
        return "spec_prd_stitch_document"
    else:
        return f"{screen_id[:8]}_{title_clean[:30]}"

def download_file(url, dest_path):
    print(f"Downloading {url[:60]}... -> {dest_path}")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as resp:
        content = resp.read()
        with open(dest_path, "wb") as out:
            out.write(content)
    print(f"  Done ({len(content)} bytes)")
    return len(content)

manifest = []

for s in screens_data.get("screens", []):
    screen_name = s.get("name", "")
    screen_id = screen_name.split("/")[-1] if "/" in screen_name else screen_name
    title = s.get("title", "Untitled Screen")
    folder_name = get_folder_name(screen_id, title)
    target_folder = os.path.join(screens_dir, folder_name)
    os.makedirs(target_folder, exist_ok=True)
    
    entry = {
        "id": screen_id,
        "name": screen_name,
        "title": title,
        "folder": f"screens/{folder_name}",
        "width": s.get("width"),
        "height": s.get("height"),
        "deviceType": s.get("deviceType"),
        "files": {}
    }
    
    # Save screen metadata
    with open(os.path.join(target_folder, "screen.json"), "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2)
    entry["files"]["metadata"] = "screen.json"
    
    # Download screenshot if available
    screenshot_url = s.get("screenshot", {}).get("downloadUrl")
    if screenshot_url:
        ss_filename = "screenshot.png"
        if "portrait" in folder_name:
            ss_filename = "portrait.png"
        ss_path = os.path.join(target_folder, ss_filename)
        size = download_file(screenshot_url, ss_path)
        entry["files"]["screenshot"] = ss_filename
        entry["files"]["screenshot_bytes"] = size

    # Download htmlCode if available
    html_entry = s.get("htmlCode", {})
    html_url = html_entry.get("downloadUrl")
    mime_type = html_entry.get("mimeType", "")
    if html_url:
        if "svg" in mime_type or screen_id == "0d87e52749864aed90ae5583c3b7e9a6":
            code_filename = "logo.svg"
        elif "markdown" in mime_type:
            code_filename = "spec.md"
        else:
            code_filename = "screen.html"
            
        code_path = os.path.join(target_folder, code_filename)
        size = download_file(html_url, code_path)
        entry["files"]["code"] = code_filename
        entry["files"]["code_mime"] = mime_type
        entry["files"]["code_bytes"] = size
        
    manifest.append(entry)

# Sort manifest by folder name
manifest.sort(key=lambda x: x["folder"])

manifest_path = os.path.join(OUTPUT_DIR, "screens_manifest.json")
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
print("Saved screens_manifest.json")

# 3. Generate README.md
readme_content = f"""# UR-Heart Stitch UI Screens & Assets

Imported from Google Stitch Project:
- **Project Title:** {project_data.get('title')}
- **Project ID:** `{PROJECT_ID}`
- **Theme:** {design_theme.get('colorMode')} | Primary: `{design_theme.get('customColor')}` | Font: `{design_theme.get('font')}`

---

## Downloaded Screens & Code

| # | Screen / Asset | Screen ID | Dimensions | Code File | Screenshot |
|---|----------------|-----------|------------|-----------|------------|
"""

for idx, m in enumerate(manifest):
    folder_rel = m['folder'].replace('\\', '/')
    code_f = m['files'].get('code', '—')
    ss_f = m['files'].get('screenshot', '—')
    code_link = f"[{code_f}]({folder_rel}/{code_f})" if code_f != '—' else '—'
    ss_link = f"[{ss_f}]({folder_rel}/{ss_f})" if ss_f != '—' else '—'
    dims = f"{m.get('width')}x{m.get('height')}" if m.get('width') else "—"
    readme_content += f"| {idx+1} | **{m['title'][:45]}** | `{m['id']}` | {dims} | {code_link} | {ss_link} |\n"

readme_content += """
---

## Design System Tokens
- Complete Stitch design tokens specifications: [`design_system.md`](design_system.md)
- Complete Stitch project metadata: [`project_info.json`](project_info.json)
- Screen manifest index: [`screens_manifest.json`](screens_manifest.json)
"""

with open(os.path.join(OUTPUT_DIR, "README.md"), "w", encoding="utf-8") as f:
    f.write(readme_content)
print("Saved README.md")
print("All Stitch screens imported successfully!")
