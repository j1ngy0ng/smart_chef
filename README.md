# smart_chef

Mobile Assignment.

## Getting Started

This project is a starting point for a Flutter application.

## Runtime configuration (`--dart-define`)

This app now reads runtime config from compile-time Dart defines (no hard-coded API keys in source):

- `SUPABASE_URL` (required)
- `SUPABASE_ANON_KEY` (required, client/publishable key only)
- `GOOGLE_WEB_CLIENT_ID` (required for Google sign-in)
- `GEMINI_API_KEY` (required for Gemini-powered features)
- `GEMINI_NUTRITION_API_KEY` (optional, falls back to `GEMINI_API_KEY`)
- `PIXABAY_API_KEY` (required for AI recipe image fetching)
- `SPOONACULAR_API_KEY` (required for waste-recipe API mode)

Use `dart_defines.example` as a template, then run:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=GEMINI_NUTRITION_API_KEY=... \
  --dart-define=PIXABAY_API_KEY=... \
  --dart-define=SPOONACULAR_API_KEY=...
```

Release builds:

```bash
flutter build appbundle \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## Android release signing setup

Release signing now requires a local `android/key.properties` file (ignored by Git).  
Create it from `android/key.properties.example` and set:

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

If missing, release builds fail with a clear Gradle error. Debug builds remain unaffected.

## Security guidance before public visibility

See [SECURITY.md](SECURITY.md) for mandatory pre-publication actions:

- Never commit secrets/signing assets
- Rotate all previously exposed credentials
- Review Supabase RLS and storage policies
- Rewrite Git history to remove old secrets

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
