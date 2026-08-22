#!/bin/bash
set -e
export PATH="$PATH:/c/Program Files/GitHub CLI"

# 1. Version Bump
CURRENT_VERSION=$(grep 'version:' mobile_app/pubspec.yaml | awk '{print $2}')
BASE_VERSION=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)
NEW_BUILD=$((BUILD_NUMBER + 1))

IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
NEW_TAG="v${NEW_VERSION}"

echo "Auto-bumping version: $CURRENT_VERSION -> ${NEW_VERSION}+${NEW_BUILD}"
sed -i.bak "s/version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" mobile_app/pubspec.yaml && rm -f mobile_app/pubspec.yaml.bak

# 2. Build Split Release APKs
echo "Building split APKs..."
cd mobile_app
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
cd ..

# 3. Update Backend System Route for In-App Updates
sed -i.bak "s/\"latest_version\": \".*\"/\"latest_version\": \"${NEW_VERSION}\"/" backend/app/api/v1/system.py || true
sed -i.bak "s|download/v.*/UR-Heart-arm64-v8a.apk|download/${NEW_TAG}/UR-Heart-arm64-v8a.apk|" backend/app/api/v1/system.py || true
rm -f backend/app/api/v1/system.py.bak

# 4. Git Push & Publish Release Assets
git add .
git commit -m "chore(release): automated build ${NEW_TAG}" || true
git tag -f ${NEW_TAG}
git push origin main --tags

echo "Publishing ${NEW_TAG} to GitHub Releases..."
gh release delete ${NEW_TAG} -y --repo anubhav7773/UR-Heart || true
gh release create ${NEW_TAG} \
  "mobile_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk#UR-Heart-arm64-v8a.apk" \
  "mobile_app/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk#UR-Heart-armeabi-v7a.apk" \
  "mobile_app/build/app/outputs/flutter-apk/app-x86_64-release.apk#UR-Heart-x86_64.apk" \
  --repo anubhav7773/UR-Heart \
  --title "UR-Heart ${NEW_TAG} — Automated Testing Build" \
  --notes "Automated build ${NEW_TAG}:
- Sentry SocketException & DNS drops handled safely.
- In-App auto update enabled."

echo "Release ${NEW_TAG} live on GitHub!"
