# Releasing SRMOne Mobile

## One-time: the Android release key

Every release must be signed with the same key, or Android refuses to install
it over the previous version. Create the key once, on your own PC, and keep a
backup somewhere safe (losing it means every user has to reinstall):

```bash
keytool -genkey -v -keystore srmone-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias srmone
```

Add four repository secrets (GitHub → Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the .jks file as base64 (`base64 -w0 srmone-release.jks`, or on Windows `[Convert]::ToBase64String([IO.File]::ReadAllBytes("srmone-release.jks"))`) |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `srmone` |
| `ANDROID_KEY_PASSWORD` | the key password |

For local release builds, put the same values in `android/key.properties`
(git-ignored), with `storeFile` relative to `android/`:

```properties
storeFile=srmone-release.jks
storePassword=...
keyAlias=srmone
keyPassword=...
```

Without a key, local and branch builds fall back to the debug key; tag builds
fail instead of publishing an APK that can't update.

## Each release

1. Bump `version:` in `pubspec.yaml` (the name, e.g. `1.0.3+3`). CI sets the
   build number from the run number, so it always increases.
2. Merge to `main`, then push a tag: `git tag v1.0.3 && git push origin v1.0.3`.
3. The workflow builds, signs and publishes the GitHub Release.

## Schema changes

Bump `AppDatabase.currentSchemaVersion`, add the `onUpgrade` step, then:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/database/generated/
flutter test test/database
```
