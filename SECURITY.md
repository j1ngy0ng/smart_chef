# Security for Public Repository Readiness

## Never commit these to Git

- API keys (Gemini, Pixabay, Spoonacular, Supabase service-role keys, etc.)
- OAuth client secrets
- Provider configuration files that contain secrets (for example Huawei AG Connect JSON files)
- Signing keys, keystores, and `key.properties`

Use local-only configuration (`--dart-define`, local files, CI secrets) instead.

## Mandatory manual actions before making this repository public

Credentials previously committed in this repository history must be treated as compromised.

1. Revoke/rotate all exposed credentials, including:
   - Gemini API keys
   - Pixabay API keys
   - Spoonacular API keys
   - Huawei/AG Connect credentials
   - Any other discovered credentials in commits, branches, tags, artifacts, or releases
2. Review Supabase security:
   - Ensure Row Level Security (RLS) is enabled and correct for every table
   - Review Storage bucket policies and access rules
   - Confirm no Supabase service-role key is present in client code or history
3. Rewrite Git history to remove old secrets (deleting files in current HEAD is not enough), for example:

```bash
git filter-repo --path android/app/agconnect-services.json --invert-paths
```

Then run a full history secret scan, for example:

```bash
gitleaks git --redact --verbose
```

## Local setup

- Use `dart_defines.example` to supply runtime values with `flutter run/build --dart-define=...`
- Use `android/key.properties.example` to create local `android/key.properties` for release signing
- Do not commit either real secrets or generated signing material
