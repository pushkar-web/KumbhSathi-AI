# KumbhSathi AI — Missing-Person Incident Management & Decision Support OS

### Developed for Kumbh Mela 2027

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/pushkar-web/KumbhSathi-AI?color=orange&logo=github)](https://github.com/pushkar-web/KumbhSathi-AI/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-blue.svg?logo=android)](https://github.com/pushkar-web/KumbhSathi-AI/releases/tag/v2.0.0)
[![Tech Stack](https://img.shields.io/badge/Stack-Flutter%20%7C%20FastAPI%20%7C%20PostgreSQL-teal.svg)](https://github.com/pushkar-web/KumbhSathi-AI)

KumbhSathi AI is an enterprise-grade, high-reliability, and offline-first decision support and incident management operating system designed for the high-density crowds of **Kumbh Mela 2027**. Its primary objective is to streamline the registration, tracking, identification, and reunion of missing individuals in environments with severely degraded network connectivity.

---

## 📱 Download & Test the Android App

If you want to download and test the Android mobile app, you can download the compiled production APK directly from the latest release:

📥 **[Download KumbhSathi AI Release APK (v2.0.0)](https://github.com/pushkar-web/KumbhSathi-AI/releases/download/v2.0.0/app-release.apk)**

> **Note:** Since this is a production-compiled package, you may need to allow installation from unknown sources in your Android security settings.

---

## 🆕 What's New in v2.0.0

### Premium Splash Screen & Onboarding
* **Branded Splash Screen**: A beautiful full-bleed gradient splash with the KumbhSathi AI logo, animated entry, and auto-navigation — appears every time the app launches.
* **3-Page Onboarding Flow**: First-time users are guided through the app's core capabilities: Missing Person Tracking, AI-Powered Face Matching, and Offline-First Architecture — with smooth page transitions and accent-highlighted indicators.
* **Smart Navigation**: Splash → Onboarding (first install only) → Register → Login → Role Dashboard. Returning users skip onboarding automatically.

### Auth Flow Improvements
* **OTP Flow Removed**: Simplified authentication — direct password-based login for reliability in low-connectivity environments.
* **Role-Based Dashboard Redirect**: After login, users are automatically routed to their specific role dashboard (Family, Police, Volunteer, or Admin).
* **Logout Accessible Everywhere**: Logout button now prominently visible on every role's navigation bar with confirmation dialog.

### App Identity
* **Custom App Icon**: New branded launcher icon with adaptive icon support — appears correctly on all Android home screens and app drawers.
* **App Name**: Home screen now displays "KumbhSathi AI" instead of package name.

---

## 🌟 Core System Highlights

### 1. Hybrid AI Orchestration (Online & Offline)
* **Online Mode**: Offloads heavy AI interview translation, profiling, and summary generation to **Groq Cloud** using the `llama-3.3-70b-versatile` model for lightning-fast, high-quality analysis.
* **Offline-First Fallback**: If network signals fail, the app automatically switches to run **Gemma 3n on-device** (using `flutter_gemma` and MediaPipe LLM Inference) to conduct interviews and summarize reports.
* **Dynamic AI Chip**: A persistent status badge indicates whether AI flows are running via Cloud, On-Device, or are temporarily unavailable.

### 2. On-Device Face Recognition (Biometrics)
* Fully offline face embedding generation and similarity matching.
* Detects faces using Google ML Kit and extracts **192-dimensional embeddings** using a local **MobileFaceNet** (TFLite) model.
* Performs quick-match queries locally using **cosine similarity** against a local **Hive index** of missing-person cases.

### 3. Secure, Offline Aadhaar Scanning & Verification
* **OCR-Based Scan**: Captures Aadhaar card details locally via ML Kit Text Recognition.
* **Verhoeff Checksum Validation**: Instantly checks numeric integrity using the Verhoeff algorithm to eliminate human typos.
* **Secure QR Parsing**: Inflates encrypted UIDAI QR code binaries (BigInt → zlib decompression) to extract verification fields.
* **Privacy-First**: No plaintext Aadhaar numbers are stored (only salted SHA-256 hashes). Raw card photos never leave the mobile device.

### 4. Reliable Offline Sync Queue
* Integrates a local **Hive sync queue** that registers all write requests (registrations, updates, status changes) when offline.
* Optimistically updates the UI with a "will sync" indicator and uploads all queued payloads automatically as soon as internet connection is restored.

---

## 🏗️ Architecture & Directories

This repository contains a mobile application (Flutter) and a microservice backend (FastAPI):

```
KumbhSathi-AI/
│
├── kumbhsathi_app/             # Flutter Mobile Client (Android & Web)
│   ├── lib/
│   │   ├── features/           # Portals: family, volunteer, police, admin
│   │   │   ├── auth/screens/   # Splash, Onboarding, Login, Register
│   │   │   └── shell/          # Role-aware navigation shell
│   │   ├── core/theme/         # Sanctum Design System v2 colors & typography
│   │   ├── providers/          # Riverpod state management & wiring
│   │   ├── services/           # Face matching, Aadhaar parsing, AI Orchestration
│   │   └── shared/widgets/     # Reusable custom UI components (cards, badges, etc.)
│   └── web/                    # Flutter web Portal setups
│
├── backend/                    # Python FastAPI REST Server
│   ├── app/
│   │   ├── api/v1/             # Endpoints (notifications, map data, cases)
│   │   ├── core/               # Configuration settings
│   │   └── ai/                 # Face embeddings, OCR models
│   └── Dockerfile              # Containerization recipe
│
├── database/                   # Schema scripts & migrations
├── data/                       # Mock data files (CCTV, Police stations, etc.)
└── docker/                     # Docker Compose development setups
```

---

## 🛠️ Installation & Local Setup

### Prerequisites
* Flutter SDK (≥ 3.27)
* Dart SDK (≥ 3.6)
* Python (≥ 3.10)
* Docker & Docker Compose (optional, for backend services)

### 1. Flutter Mobile App Setup

1. Navigate to the app directory:
   ```bash
   cd kumbhsathi_app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the development build:
   * **Android Emulator/Device (Recommended)**:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
     ```
   * **Web Portals Preview**:
     ```bash
     flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
     ```

### 2. Python FastAPI Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the FastAPI development server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

Alternatively, you can run the entire backend and database stack using Docker Compose:
```bash
docker-compose -f docker/docker-compose.yml up --build
```

---

## 🤝 Verification & Code Quality

The codebase has undergone a rigorous, adversarial-grade verification process to ensure compatibility:
1. **Design Tokens Audit**: Verified that all custom views, forms, and widgets utilize strict **Sanctum Design System v2** variables.
2. **Provider Lifecycle & Syncing**: Ensured Riverpod provider states are thoroughly disposed of and offline queues successfully sync sequentially.
3. **Graceful Degradation**: Tested to ensure features degrade gracefully (without crashes) when offline and without models.

---

## 📄 License
This project is proprietary and developed exclusively for the Kumbh Mela 2027 Security and Missing-Person Incident Management operations.
