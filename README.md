# SRM One — Local-First Academic Companion

A 100% **Local-First, Zero-Server Native Mobile Application (iOS & Android)** for SRM students, built with Flutter and Dart.

```
       _____ _____  __  __  ____             
      / ____|  __ \|  \/  |/ __ \            
     | (___ | |__) | \  / | |  | |_ __   ___ 
      \___ \|  _  /| |\/| | |  | | '_ \ / _ \
      ____) | | \ \| |  | | |__| | | | |  __/
     |_____/|_|  \_\_|  |_|\____/|_| |_|\___|  MOBILE
```

---

## 🚀 Key Highlights

- **Zero-Server & $0/Month Hosted Cost**: Zero middleman servers, zero telemetry relays, zero hosted databases. Direct on-device HTTPS requests to official SRM portals (`academia.srmist.edu.in` and `sp.srmist.edu.in`).
- **Hardware-Backed Privacy**: Passwords and session cookies are encrypted using physical device security (iOS Keychain Secure Enclave / Android Keystore).
- **On-Device ONNX CAPTCHA Solver**: Solves Student Portal CAPTCHAs in ~80ms locally on-device using a bundled `ddddocr` ONNX CTC inference engine without sending images to third-party OCR services.
- **Offline-First Reactive SQLite**: 10 local tables powered by `Drift` with reactive streams. View timetables, attendance trends, and marks instantly with zero network latency.
- **Biometric Security**: Optional FaceID, TouchID, and Fingerprint app lock.
- **Automated Cloud CI/CD**: Preconfigured GitHub Actions workflow builds unsigned iOS `.ipa` and split Android release APKs on every push.

---

## 🛠 6 Verified Core Fixes over Legacy Web

| Bug Fix | Legacy Web Version | SRM One Mobile |
| :--- | :--- | :--- |
| **#1 Zero-Logout SWR** | Failed to update attendance until manual logout/login | 4-Layer Stale-While-Revalidate with silent re-auth; never forces logout |
| **#2 T=100% Planner Guard** | Division by zero `(100 - T)` caused `NaN` / crash | Guards `T=100` and flags mathematical impossibility when absences $> 0$ |
| **#3 Dual Attendance Metrics** | Mixed up weighted vs unweighted mean | Displays both unweighted mean and weighted overall % clearly |
| **#4 Unified Calendar Resolver**| Conflicting holiday logic between front/backend | Single authoritative `CalendarDayResolver` using local dates |
| **#5 Reactive Unread Notifications**| Manual inc/dec caused negative drift on updates | Drift SQLite reactive streams compute true unread count |
| **#6 Isolated Marks Models** | Overwrote internal tests with semester grades | Separate isolated tabs for Academia tests vs SP semester marks |

---

## 📂 Repository Structure

```text
SRMOne/
├── .github/workflows/
│   └── mobile_build.yml          # GitHub Actions CI/CD (Android APK + iOS IPA)
├── srmone_mobile/                # 📱 100% LOCAL-FIRST FLUTTER APPLICATION
│   ├── assets/
│   │   ├── images/logo.png       # Shipped brand logo
│   │   ├── illustrations/        # 13 pruned SVG vector illustrations
│   │   └── ml/                   # ddddocr ONNX model & CTC charset
│   ├── lib/
│   │   ├── core/                 # SQLite DB, Keychain Vault, Network client
│   │   ├── domain/               # Planner math, Calendar resolver, Sync orchestrator
│   │   ├── scrapers/             # Pure Dart scrapers (Academia, SP, Faculty)
│   │   └── features/             # UI screens (Overview, Attendance, Timetable, Marks, etc.)
│   └── test/                     # 44 passing unit & widget smoke tests
├── academia-backend/             # [Archived Reference] Legacy Node + Go + React code
├── architecture.md               # Detailed mobile system architecture & schema
├── plan.md                       # Comprehensive phased execution plan
├── SCRAPER_SPEC.md               # Reverse-engineered portal scraping specification
└── IOS_BUILD_GUIDE.md            # iOS cloud build & sideloading instructions
```

---

## ⚡ Quick Start (Local Development)

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ (Dart 3.5+)
- Android Studio / Xcode

### Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/SRMOne.git
   cd SRMOne/srmone_mobile
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Generate Drift SQLite DAOs & Models**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run Unit & Widget Test Suite**:
   ```bash
   flutter test
   ```

5. **Launch the Application**:
   ```bash
   flutter run
   ```

---

## 📦 Building Releases

### Android APK / App Bundle

```bash
cd srmone_mobile
flutter build apk --release --split-per-abi
```
Generated APKs are located at `srmone_mobile/build/app/outputs/flutter-apk/`.

### iOS Unsigned `.ipa` (for Sideloadly / AltStore / TrollStore)

Build locally on macOS without an Apple Developer account:
```bash
cd srmone_mobile
flutter build ios --release --no-codesign
cd build/ios/iphoneos
mkdir Payload
cp -r Runner.app Payload/
zip -r -y SRMOne-iOS-Unsigned.ipa Payload
```
Or push to GitHub to let GitHub Actions compile and package the `.ipa` automatically.

---

## 🛡 Privacy & Security

- **Zero Third-Party Relays**: All network requests originate directly from the student's physical device to SRMIST endpoints.
- **Hardware Enclave**: Credentials are stored in AES-256 encrypted hardware keystores.
- **Open Source & Auditable**: Every line of scraping and networking code is transparent.

---

## 📜 License

This project is licensed under the MIT License. It is an independent, open-source utility developed for student academic productivity and is not affiliated with or endorsed by SRM Institute of Science and Technology.
