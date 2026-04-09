# SafeNest – AI-Based Child Safety Mobile App

This project consists of three main components:
1.  **Mobile Application (Flutter)**: A cross-platform mobile app for iOS and Android.
2.  **AI Module (Python)**: A machine learning module for gesture-based user detection.
3.  **Backend (Express/Node.js)**: A server handling alerts, reports, and AI analysis.

---

## 📱 1. Flutter Mobile App
The complete Flutter source code is located in the `/flutter_app` directory.

### Setup Instructions:
1.  **Install Flutter**: Follow the [official guide](https://docs.flutter.dev/get-started/install).
2.  **Configure Supabase**:
    -   Create a project at [supabase.com](https://supabase.com).
    -   Run the SQL script in `backend/setup.sql` in the Supabase SQL Editor.
    -   Update `lib/main.dart` with your `url` and `anonKey`.
3.  **Run the App**:
    ```bash
    cd flutter_app
    flutter pub get
    flutter run
    ```

---

## 🧠 2. Python AI Module
The AI module is located in the `/ai_module` directory. It uses a Random Forest model to detect if a user is a child or an adult based on touch gestures.

### Setup Instructions:
1.  **Install Dependencies**:
    ```bash
    pip install numpy scikit-learn
    ```
2.  **Train & Predict**:
    ```bash
    cd ai_module
    python predict.py
    ```
    This will generate a synthetic dataset, train the model (`user_type_model.pkl`), and run test predictions.

---

## ⚙️ 3. Backend Integration
The backend is a Node.js Express server (`server.ts`) that provides API endpoints for the mobile app.

### API Endpoints:
-   `POST /api/send_sos`: Triggers an emergency alert.
-   `POST /api/submit_report`: Stores a safety report and returns AI analysis.
-   `POST /api/predict_user_type`: Simulates the gesture detection logic.

---

## 🛠️ 4. Project Structure
-   `/flutter_app/`: Full Flutter project (screens, widgets, services).
-   `/ai_module/`: Python ML training and prediction scripts.
-   `/server.ts`: Full-stack backend server.
-   `/src/App.tsx`: High-fidelity mobile simulator for web preview.

---

## 🍏 5. Step-by-Step: Run on iPhone (Local Development)

To run this app on your iPhone without publishing to the App Store, follow these steps:

### Prerequisites (Mac Required for iOS):
1.  **Install Xcode**: Download it from the Mac App Store.
2.  **Install Flutter**: Follow the [macOS Flutter Install](https://docs.flutter.dev/get-started/install/macos).
3.  **CocoaPods**: Install via terminal: `sudo gem install cocoapods`.

### Setup Steps:
1.  **Open Project**:
    ```bash
    cd flutter_app
    flutter pub get
    ```
2.  **Configure iOS Folder**:
    ```bash
    cd ios
    pod install
    cd ..
    ```
3.  **Open in Xcode**:
    -   Open `ios/Runner.xcworkspace` in Xcode.
4.  **Signing & Capabilities**:
    -   In Xcode, select the **Runner** project in the left sidebar.
    -   Go to **Signing & Capabilities**.
    -   Click **+ Capability** and add "Push Notifications" if needed.
    -   Select your **Team** (Personal Team is fine).
    -   Change the **Bundle Identifier** to something unique (e.g., `com.yourname.safenest`).
5.  **Connect iPhone**:
    -   Plug your iPhone into your Mac.
    -   On your iPhone, "Trust" the computer.
6.  **Trust Developer**:
    -   The first time you run, it will fail saying "Untrusted Developer".
    -   On iPhone, go to **Settings > General > VPN & Device Management**.
    -   Tap your Apple ID and select **Trust "Apple Development: [Your Email]"**.
7.  **Run the App**:
    -   In your terminal (inside `flutter_app` folder):
    ```bash
    flutter run
    ```
    -   Select your iPhone from the list.

---

## 🤖 6. Step-by-Step: Run on Android (Windows/Linux/Mac)

Since you don't have a Mac, **Android is the best way to show a real app**. You can run this on any Windows, Linux, or Mac computer.

### Prerequisites:
1.  **Install Flutter**: Follow the [Windows Flutter Install](https://docs.flutter.dev/get-started/install/windows).
2.  **Android Studio**: Download and install [Android Studio](https://developer.android.com/studio).
3.  **Android SDK**: Inside Android Studio, ensure the Android SDK and Command-line Tools are installed.

### Setup Steps:
1.  **Enable Developer Mode on Phone**:
    -   Go to **Settings > About Phone**.
    -   Tap **Build Number** 7 times until it says "You are now a developer".
    -   Go to **Settings > System > Developer Options** and enable **USB Debugging**.
2.  **Connect Phone**:
    -   Plug your Android phone into your PC via USB.
    -   Select "File Transfer" mode on the phone.
3.  **Run the App**:
    -   Open your terminal in the `flutter_app` folder:
    ```bash
    flutter pub get
    flutter run
    ```
    -   The app will compile into an APK and install on your phone automatically.

---

## 🌐 7. The "Instant Demo" (No Install Required)

If you need to show the app **right now** for your project review without any setup:

1.  **Open the Shared URL**: Open this link on your Android phone's Chrome browser:
    `https://ais-pre-c5hs4smybxwinblsyihidl-111644439935.asia-southeast1.run.app`
2.  **Add to Home Screen**:
    -   Tap the **three dots** in Chrome.
    -   Select **"Add to Home Screen"**.
3.  **Demo**: This will create an icon on your phone that opens the **High-Fidelity Simulator**. It looks and behaves exactly like a real app and is perfect for a quick project review!

---

## 🎯 Final Output Goal
By following these instructions, you can:
1.  **Run the Flutter app** on a real device or emulator.
2.  **Connect to Supabase** for real-time data storage.
3.  **Run the AI model** locally to classify user gestures.
4.  **Demo the full flow** (SOS -> Report -> AI Detection) using the provided simulator or the native app.
