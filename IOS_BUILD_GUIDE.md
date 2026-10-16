# IOS_BUILD_GUIDE.md — Building & Deploying `SRMOne` for iPhone (iOS) from Windows

Because you are developing on Windows (`.ps1` scripts in `SRMOne`) and Apple requires macOS + Xcode to compile iOS `.ipa` binaries, this guide sets up an **automated zero-Mac cloud build pipeline** using **GitHub Actions (`macos-14` runner)** directly inside your forked `SRMOne` repository.

---

## 1. Required iOS `Info.plist` Permissions (`srmone_mobile/ios/Runner/Info.plist`)

The coding agent must add these exact keys inside `<dict>` in `srmone_mobile/ios/Runner/Info.plist`:

```xml
<!-- FaceID / TouchID Biometric App Lock -->
<key>NSFaceIDUsageDescription</key>
<string>SRMOne uses Face ID to protect your academic dashboard and stored credentials.</string>

<!-- Saving Exported Timetable PNG to Photos -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>SRMOne saves your generated timetable image to your Photo Library.</string>

<!-- 1-Tap Apple Calendar Sync (Phase 5) -->
<key>NSCalendarsUsageDescription</key>
<string>SRMOne syncs your academic day orders and class schedule to your Calendar.</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>SRMOne syncs your academic day orders and class schedule to your Calendar.</string>

<!-- Background Attendance Refresh -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>in.srmone.mobile.attendanceSync</string>
</array>
```

---

## 2. Two Ways to Install on Your iPhone Without a Mac

### Option A: Sideload on Personal iPhone via AltStore / SideStore / Sideloadly (Free, No $99 Apple Account Needed)
1. Push your code to your forked GitHub repository.
2. GitHub Actions (`macos-14` runner below) compiles the **Unsigned `SRMOne-unsigned.ipa`** and uploads it as a downloadable artifact on your GitHub Actions run page.
3. Download `SRMOne-unsigned.ipa` on your Windows PC and install it onto your iPhone over Wi-Fi/USB using **Sideloadly** or **AltStore** with your free Apple ID.

### Option B: Official TestFlight / App Store Distribution (With Apple Developer Account)
1. Add your App Store Connect API Key (`APP_STORE_CONNECT_KEY_ID`, `ISSUER_ID`, `PRIVATE_KEY`) and Certificate/Provisioning Profile to GitHub Repo Secrets (or connect your forked GitHub repo to **Codemagic.io**'s free tier, which handles automatic iOS code-signing in the browser without needing a Mac to generate certificates).

---

## 3. Ready-to-Use GitHub Actions Workflow (`.github/workflows/mobile_build.yml`)

Have your coding agent create `.github/workflows/mobile_build.yml` at the root of the forked repository:

```yaml
name: Build SRMOne Mobile (Android APK & iOS IPA)

on:
  push:
    branches: [ main ]
    paths:
      - 'srmone_mobile/**'
      - '.github/workflows/mobile_build.yml'
  workflow_dispatch:

jobs:
  build-android:
    name: Build Android Release APK
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: srmone_mobile
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - name: Install dependencies & generate Drift/Freezed code
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs
      - name: Run Unit Tests
        run: flutter test
      - name: Build Split APKs
        run: flutter build apk --release --split-per-abi
      - name: Upload Android APKs
        uses: actions/upload-artifact@v4
        with:
          name: SRMOne-Android-APKs
          path: srmone_mobile/build/app/outputs/flutter-apk/*.apk

  build-ios:
    name: Build iOS IPA (macOS Cloud Runner)
    runs-on: macos-14
    defaults:
      run:
        working-directory: srmone_mobile
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - name: Install dependencies & generate code
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs
      - name: Install CocoaPods
        run: |
          cd ios
          pod install
      - name: Build iOS Release (No Codesign)
        run: flutter build ios --release --no-codesign
      - name: Package Unsigned .ipa for Sideloadly / AltStore
        run: |
          mkdir -p build/ios/iphoneos/Payload
          cp -r build/ios/iphoneos/Runner.app build/ios/iphoneos/Payload/
          cd build/ios/iphoneos
          zip -r -y SRMOne-iOS-Unsigned.ipa Payload
      - name: Upload iOS IPA Artifact
        uses: actions/upload-artifact@v4
        with:
          name: SRMOne-iOS-IPA
          path: srmone_mobile/build/ios/iphoneos/SRMOne-iOS-Unsigned.ipa
```

---

## 4. Extracting `ddddocr_common.onnx` Once on Windows (Setup Helper Script)

During Phase 0, the coding agent can run this one-liner in your local Python environment (where `ddddocr` is installed for `solve_captcha.py`) to copy the exact `ddddocr` ONNX model into the Flutter assets folder:

```powershell
python -c "import ddddocr, shutil, pathlib, inspect; pkg_dir = pathlib.Path(inspect.getfile(ddddocr)).parent; target = pathlib.Path('srmone_mobile/assets/ml'); target.mkdir(parents=True, exist_ok=True); [shutil.copy(f, target / f.name) for f in pkg_dir.glob('*.onnx')]; print('Copied ONNX models:', list(target.glob('*.onnx')))"
```