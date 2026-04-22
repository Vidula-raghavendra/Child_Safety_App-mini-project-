# SafeNest – Smart Child Safety

SafeNest is a production-grade safety application designed to protect children through real-time location monitoring, SOS alerting, and AI-powered report analysis. This prototype facilitates a secure, linked relationship between a Parent and a Child account.

## 🚀 Core Features

- **Dynamic Account Linking**: Secure 6-digit handshake protocol between parent and child devices.
- **Real-Time GPS Tracking**: Background location broadcasting from child devices to parent dashboards using Firestore.
- **AI-Powered Safety Analysis**: Uses **Google Gemini 3 Flash** to analyze child-submitted reports and provide instant risk assessment and advice.
- **SOS Panic System**: A high-pressure hold-to-trigger SOS system that instantly alerts the parent with the child's exact coordinates.
- **Bi-Directional Sync**: Real-time updates across devices using Firebase `onSnapshot` listeners.

## 💻 Tech Stack

- **Frontend**: React 19 + TypeScript + Vite.
- **Styling**: Tailwind CSS (Modern Utility-First UI).
- **Backend/Database**: Firebase Firestore (NoSQL) & Firebase Auth (Google Sign-In).
- **AI**: Google Gemini API (@google/genai).
- **Animations**: Framer Motion (for professional iOS-style transitions).
- **Icons**: Lucide React.
- **Full-Stack Runtime**: Node.js + Express (Server-side middleware).

## 🛠️ Local Setup Instructions

Follow these steps to run SafeNest on your local machine:

### 1. Prerequisites
- Install [Node.js](https://nodejs.org/) (v18 or higher recommended).
- A Firebase project (or use the one provided in the config).

### 2. Installation
Clone the repository and install dependencies:
```bash
npm install
```

### 3. Environment Variables
Create a `.env` file in the root directory (use `.env.example` as a template):
```env
GEMINI_API_KEY=your_gemini_api_key_here
```

### 4. Running the App
Start the development server:
```bash
npm run dev
```
The app will be accessible at `http://localhost:3000`.

---

## 📂 Codebase Walkthrough (Academic Guide)

### 1. The Entry Point: `server.ts`
The application uses a full-stack architecture. `server.ts` handles the Express backend which integrates Vite as middleware. This allows us to handle API routes and environment variables (like the Gemini API Key) securely on the server side.

### 2. Main Logic: `src/App.tsx`
This is the "Brain" of the application. It manages:
- **Authentication State**: Using `onAuthStateChanged` to track user login status.
- **App State Machine**: Transitions between `landing` -> `onboarding` -> `linking` -> `main`.
- **Real-time Sync**: Uses `onSnapshot` for bi-directional updates. When a child moves or triggers SOS, the parent's UI re-renders instantly without a refresh.

### 3. Location Sharing: `useLocationSharing` (Hook)
Found in `App.tsx`, this custom hook handles the complex logic of:
- Starting/stopping GPS tracking on child devices.
- Broadcasting coordinates to Firestore.
- Subscribing to moves on parent devices.

### 4. AI Engine: `src/services/safetyService.ts`
Integrates the **Google Gemini API**. When a child submits a report, the text is sent to the AI, which acts as a "Digital Guardian," classifying the risk and giving immediate safety instructions before a parent even sees the alert.

### 5. Data Security: `firestore.rules`
This file defines the **Security Architecture**. It ensures:
- Only a linked parent can read their child’s location.
- Linking codes are one-time use and protected against brute force.
- Users can only read/write their own data.

## 🔒 Firebase Configuration
The `firebase-applet-config.json` contains the project-specific keys. The database structure is defined in `firebase-blueprint.json` (Internal Representation).

---

## 🎓 Faculty Presentation Guide
- **Real-time Aspect**: Demonstrate how clicking "SOS" on the Child "Phone" (tab 1) reflects *instantly* on the Parent (tab 2).
- **AI Integration**: Submit a report like "I feel like someone is following me" and show the immediate AI advice provided.
- **Security**: Explain the "Handshake" linking code and how it prevents random people from tracking kids.
