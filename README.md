# Fitzyy

A Flutter calorie and nutrition companion with a glassmorphism interface. The app supports Google OAuth through Supabase, user-owned nutrition data, custom foods, personal habits, daily macro goals, and scan history.

## Backend setup

This project uses **Supabase**. Put your public Supabase values once in [`lib/config/supabase_config.dart`](lib/config/supabase_config.dart). The app reads that file automatically on every run, so you do not need to add `--dart-define` arguments repeatedly.

The file must contain the Project URL and the public publishable/anon key. Never put a `service_role` key in the Flutter app.

### 1. Create the database

1. Create a project at [supabase.com](https://supabase.com/).
2. Open **SQL Editor**.
3. Run [`supabase/schema.sql`](supabase/schema.sql).

The schema creates profiles, preferences, settings, custom foods, habits, habit logs, and scan records. Row Level Security ensures each signed-in user can only access their own rows.

### 2. Configure Google sign-in in Supabase

1. In Supabase, open **Authentication > Providers > Google** and enable Google.
2. Create a Google OAuth web client in Google Cloud Console.
3. Add this Supabase callback URL to Google:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

4. In Supabase **Authentication > URL Configuration**, add this mobile redirect URL:

```text
io.omnirush.caloriescan://login-callback
```

Keep the Google client secret in Supabase only. Never add it to Flutter, source control, or a dart-define.

### 3. Add your values once

Open:

```text
lib/config/supabase_config.dart
```

Replace these two placeholders:

```dart
static const url = 'PASTE_SUPABASE_PROJECT_URL_HERE';
static const publishableKey = 'PASTE_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE';
```

with the values from **Project Settings → API**.

The URL must be only the project root, for example:

```text
https://YOUR_PROJECT_REF.supabase.co
```

Do not append `/rest/v1/`, `/auth/v1/`, or any other path. The Flutter Supabase client adds those paths itself.

### 4. Run the app

The normal run command is now just:

```bash
flutter pub get
flutter run
```

Android Studio can also run the project normally without additional arguments.

Optional: command-line `--dart-define` values still override the file values when supplied.

If the values are omitted, the app deliberately starts in local demo mode so the UI can still be previewed. Demo mode does not write to Supabase.

## User-controlled data

When Supabase is configured and the user signs in, the app loads and writes:

- Google-authenticated account and profile name
- Daily calorie, protein, carbohydrate, and fat targets
- Privacy setting
- Custom foods with complete nutrition details
- Custom habits
- Saved scan records and their nutrition snapshots

Custom foods can be edited or deleted from **Profile > Edit goals, foods & habits**. Editing updates the same Supabase row; deleting removes only that item from the personal food library and does not rewrite saved scan history.

The screen under **Profile > Edit goals, foods & habits** is the entry point for personalization. Defaults are database defaults for a new account, not hardcoded personal data.

## Mobile OAuth configuration

The project already contains the mobile callback configuration:

- Android intent filter in `android/app/src/main/AndroidManifest.xml`
- iOS URL scheme in `ios/Runner/Info.plist`

The Google provider and Supabase redirect URL still need to be enabled in your own Supabase and Google Cloud projects.

## AI food recognition

Supabase and the camera provide storage/authentication and image capture, but they do not identify food by themselves. The project includes a secure Gemini vision adapter so the mobile app does not contain a Gemini API key:

```text
supabase/functions/analyze-food/index.ts
```

To enable arbitrary-food scanning:

1. Install and log in to the Supabase CLI.
2. From the project folder, deploy the function:

```bash
supabase functions deploy analyze-food
```

3. Store the Gemini key as a Supabase secret, not in Flutter:

```bash
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

4. Optionally choose another supported Gemini model:

```bash
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
```

The connected scanner now uses the live camera for a new meal and calls this function. It no longer forces the user to choose a saved food such as banana. Saved foods remain available for editing and reuse, but they are separate from arbitrary photo recognition.

After changing the function or its model secret, redeploy the function before testing the mobile app:

```bash
supabase functions deploy analyze-food
```

The model returns estimated calories, protein, carbohydrates, fat, fiber, sodium, ingredients, confidence, and a food rating. These are estimates from a 2D photo; portions and hidden ingredients can be uncertain, so the result screen still allows portion adjustment.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
```
