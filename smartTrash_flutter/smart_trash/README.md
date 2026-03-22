# NaqiAI

NaqiAI is a comprehensive Flutter application for smart waste management, designed for real-time visualization, data analysis, and optimization of urban waste collection. It integrates advanced features including live tracking, data analytics, report generation, push notifications, AI-powered recommendations, route optimization, and waste predictions.

---

## Key Features

### 1. **Dynamic Dashboard**
- **Overview** of bin fill levels, gas readings, temperature, humidity, and more.
- **Interactive charts** (Syncfusion, fl_chart) for visualizing trends, correlations, and distributions.
- **Key indicators**: number of full bins, trucks required, employees needed, etc.

### 2. **Advanced Analytics**
- **Population analysis**: correlation between bin usage and population by zone.
- **Environmental analysis**: gas level tracking, temperature, humidity, and environmental alerts.
- **Pattern analysis**: dynamic Markdown reports generated server-side (NLP, trends, etc.).
- **Anomaly recommendations**: automatic action suggestions when anomalies are detected (AI).

### 3. **AI Eco Assistant** *(New)*
- **Conversational AI assistant** for waste management queries and environmental guidance.
- **Voice input support** via speech-to-text for hands-free interaction.
- Provides smart tips, answers questions, and interprets data findings.

### 4. **Waste Prediction** *(New)*
- **Bin fill-level prediction**: forecasts when bins will reach capacity based on historical data.
- **Waste type prediction**: identifies the category of waste for smarter sorting and routing.
- **Smart bin search**: enables searching and filtering bins based on predicted state.

### 5. **Route Optimization** *(New)*
- **Optimized collection routes** generated automatically based on bin fill levels and location.
- **Interactive route map** for visualizing and navigating planned collection routes.
- Integrates with OpenStreetMap (`flutter_osm_plugin`) for live map rendering.
- Uses GPS location (`geolocator`) to enable real-time position tracking.

### 6. **Report Generation & Visualization**
- **On-demand PDF report generation**, downloadable on mobile and web.
- **Integrated PDF viewer** for viewing reports directly in the app (mobile/desktop).

### 7. **Push Notifications**
- **Push notifications** via Firebase Cloud Messaging for critical alerts (full bins, high gas levels, etc.).
- **Local notifications** support via `flutter_local_notifications`.

### 8. **User Management**
- **Authentication** (Firebase Auth) with Login and Sign-Up screens.
- **Role management** (admin/user) for access control to advanced features.
- **Profile settings** screen for managing user account information.

### 9. **Theming & Personalization** *(New)*
- **Dark/Light mode** support with a dynamic theme provider.
- **Google Fonts** integration for consistent, modern typography.
- User preferences saved via SharedPreferences.

### 10. **App Settings**
- **Dynamic backend URL configuration** via the app interface.
- **User preference persistence** (SharedPreferences).

---

## Technical Architecture

- **Flutter** (cross-platform: Web, Android, iOS, Desktop)
- **Backend**: REST API (e.g., FastAPI, Flask) for data aggregation and analysis
- **Firebase**: Auth, Realtime Database, Cloud Messaging
- **Syncfusion** & **fl_chart**: advanced data visualization
- **OpenStreetMap** (`flutter_osm_plugin`): interactive map rendering
- **Geolocator**: GPS-based real-time positioning
- **Speech-to-Text** (`speech_to_text`): voice input for the Eco Assistant
- **Permission management**: storage, notifications, location, microphone, etc.

---

## Main Screen Structure

| File | Description |
|---|---|
| `main.dart` | App entry point, theme & Firebase initialization |
| `home_screen.dart` | Main navigation hub |
| `login_screen.dart` | User login |
| `signup_screen.dart` | User registration |
| `waste_dashboard.dart` | Dashboard with charts and KPIs |
| `analyse_population_tab.dart` | Population analytics and correlations |
| `anomaly_recommendation_screen.dart` | AI-based anomaly recommendations |
| `patterns_analysis_viewer_screen.dart` | Dynamic Markdown analytics viewer |
| `eco_assistant_screen.dart` | Conversational AI Eco Assistant (voice + text) *(New)* |
| `prediction_screen.dart` | Bin fill-level predictions *(New)* |
| `type_prediction_screen.dart` | Waste type prediction *(New)* |
| `map_screen.dart` | Interactive OSM map of bins *(New)* |
| `optimized_route_screen.dart` | Optimized collection route display *(New)* |
| `route_map_screen.dart` | Route navigation map *(New)* |
| `final_rapport_generation_screen.dart` | PDF report generation and viewing |
| `profile_settings_screen.dart` | User profile management *(New)* |
| `app_settings.dart` | App settings and backend URL configuration |
| `theme_provider.dart` | Dark/Light theme provider *(New)* |

---

## Installation & Setup

1. **Clone the repository**

2. **Configure Firebase**

   To connect NaqiAI to Firebase:

   1. **Create a Firebase project**  
      Go to [https://console.firebase.google.com/](https://console.firebase.google.com/), create a project, and follow the setup wizard.

   2. **Add an application to your project**  
      - For web: add a web app and retrieve the configuration (`apiKey`, `authDomain`, etc.).
      - For Android/iOS: add the corresponding apps and download the config files:
        - `google-services.json` (Android)
        - `GoogleService-Info.plist` (iOS)

   3. **Place configuration files in the Flutter project**  
      - **Web**: Place the config in `web/firebase-config.js`.
      - **Mobile**:
        - `google-services.json` → `android/app/`
        - `GoogleService-Info.plist` → `ios/Runner/`

   4. **Enable required Firebase services**  
      - Authentication (Email/Password, etc.)
      - Realtime Database or Firestore
      - Cloud Messaging (for push notifications)

   5. **Verify the integration**  
      Launch the app — if configured correctly, Firebase will connect automatically.

   > **Tip**:  
   > Example configuration files are already provided (`firebase_options_web.dart`, `firebase-config.js`).  
   > Replace them with your own Firebase project keys and identifiers.

3. **Configure the backend server URL** in the app settings screen.

4. **Install dependencies**
   ```sh
   flutter pub get
   ```

5. **Run the application**
   ```sh
   flutter run -d chrome      # Web
   flutter run -d android     # Android
   flutter run -d ios         # iOS
   ```

---

## Notes

- The app requires a compatible REST API backend to function fully.
- Push notifications require Firebase Cloud Messaging configuration.
- PDF reports are generated server-side and retrieved via the API.
- Voice input (Eco Assistant) requires microphone permission on the device.
- Map and route features require location permissions and an internet connection for tile loading.

---

## Authors

- [WAM Development](https://github.com/walid-moussa55)

---

## Useful Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Syncfusion Flutter Widgets](https://github.com/syncfusion/flutter-widgets)
- [Syncfusion Charts Documentation](https://help.syncfusion.com/flutter/chart/overview)
- [Firebase for Flutter Documentation](https://firebase.flutter.dev/docs/overview)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [flutter_osm_plugin](https://pub.dev/packages/flutter_osm_plugin)
- [speech_to_text](https://pub.dev/packages/speech_to_text)

---

**NaqiAI** — Optimize urban waste management through data and artificial intelligence!

---
