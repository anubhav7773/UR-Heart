import os
import sys
import httpx

def upload_apk():
    username = os.getenv("BROWSERSTACK_USERNAME")
    access_key = os.getenv("BROWSERSTACK_ACCESS_KEY")

    if not username or not access_key:
        print("[BROWSERSTACK] Error: BROWSERSTACK_USERNAME and BROWSERSTACK_ACCESS_KEY must be set in environment variables.")
        print("Example: set BROWSERSTACK_USERNAME=your_username && set BROWSERSTACK_ACCESS_KEY=your_key")
        sys.exit(1)

    apk_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "build", "app", "outputs", "flutter-apk", "app-release.apk")
    if not os.path.exists(apk_path):
        print(f"[BROWSERSTACK] Error: APK not found at {apk_path}. Run 'flutter build apk --release' first.")
        sys.exit(1)

    file_size_mb = os.path.getsize(apk_path) / (1024 * 1024)
    print(f"[BROWSERSTACK] Uploading UR-Heart release APK ({file_size_mb:.1f} MB) to BrowserStack App Automate...")

    with open(apk_path, "rb") as f:
        files = {"file": ("app-release.apk", f, "application/vnd.android.package-archive")}
        data = {"custom_id": "URHeartReleaseApk"}
        
        with httpx.Client(timeout=180.0) as client:
            res = client.post(
                "https://api-cloud.browserstack.com/app-automate/upload",
                auth=(username, access_key),
                files=files,
                data=data
            )
            if res.status_code == 200:
                resp_json = res.json()
                print(f"\n[BROWSERSTACK] Upload Success!")
                print(f"App URL: {resp_json.get('app_url')}")
                print(f"Custom ID: {resp_json.get('custom_id')}")
            else:
                print(f"\n[BROWSERSTACK] Upload failed with status {res.status_code}: {res.text}")

if __name__ == "__main__":
    upload_apk()
