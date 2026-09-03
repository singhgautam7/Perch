# Perch

@.agents/CLAUDE.md

Perch is a fast, local-first Android link manager built in Flutter. Save links from the
Android share sheet or in-app, organise them in nested folders and tags, auto-fetch link
metadata and favicons on device, and treat every link as a small markdown note. No
account, no backend, no tracking — one SQLite file on the device.

**Stack:** Flutter (stable) · Riverpod · GoRouter · Drift (SQLite + FTS5) ·
google_fonts · on-device HTTP + HTML metadata fetch. Package `com.grs.perch`, Android only.

**UI source of truth:** `/specs/design/` — read it before building or changing any screen.
Detailed engineering rules live in `.agents/CLAUDE.md` (imported above).

## Commands

```bash
flutter run                                              # run on a device
flutter analyze                                          # lints must stay clean
flutter test                                             # unit + widget tests
dart run build_runner build --delete-conflicting-outputs # Drift codegen
dart run flutter_launcher_icons                          # launcher icon
dart run flutter_native_splash:create                    # splash
flutter build apk --release
```

## Layout

```
lib/app/        App widget, router wiring, bootstrap
lib/core/       db (Drift, DAOs, migrations) · theme (tokens, themes) · services · router · utils
lib/shared/     common widgets used across features
lib/features/   links · folders · link_detail · add_link · search · stats · settings · onboarding
```
