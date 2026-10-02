# SafeNest — Android Child-Safety App

A Flutter app that links parent and child accounts so parents can set safe zones, see live status, and get alerted the moment a child needs help.

## Features

- **Parent–child linking** — a parent links to a child's account; each side gets its own view.
- **Live parent dashboard** — child status, zone events, check-ins and shared locations in one place.
- **Geofenced safe zones** — parents draw zones on a map. The child's device checks its location against them in the background **every 30 seconds** and notifies the parent on entry or exit.
- **SOS, two ways**
  - one-tap SOS button
  - shake-to-SOS using the accelerometer
  
  Either one fires SMS, phone calls and notifications to the child's emergency contacts.
- **Emergency contacts and incident reports** managed in-app.

## Tech stack

| Layer | Tools |
|---|---|
| App | Flutter, Dart (~7,400 lines) |
| Backend | Supabase (auth, Postgres, Row Level Security) |
| Device | geolocator, sensors_plus, flutter_local_notifications, permission_handler, url_launcher |
| Maps | flutter_map, latlong2 |

## Screens

Onboarding · Login · Home (with SOS) · Link Child · Parent Dashboard · Safe Zones · Add Zone · Emergency Contacts · Report · Status

## Repository layout

```
flutter_app/            the Android app (main product)
  lib/screens/          one file per screen
  lib/services/         zone_monitor.dart (background geofence checks), notification_service.dart
  lib/widgets/          sos_button.dart
backend/
  supabase_setup.sql    tables, Row Level Security policies
ai_module/              early prototype: gesture-based user detection
src/, server.ts         early web prototype (Vite + Express)
```

## Running the app

1. Create a Supabase project and run `backend/supabase_setup.sql` in its SQL editor. This creates the tables and the Row Level Security policies.
2. Put your project URL and anon key in `flutter_app/lib/main.dart`.
3. Run the app:

   ```bash
   cd flutter_app
   flutter pub get
   flutter run
   ```

The Supabase anon key is safe to ship in a client app because every table is protected by Row Level Security. Never put the `service_role` key in the app.

## Permissions

The app asks for location (including background location for zone checks), notifications, SMS and phone access so SOS alerts can reach emergency contacts.
