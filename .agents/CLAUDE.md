# Perch — Engineering Guidelines

Source of truth for how code in this repo is written. Read before changing anything.

## Design adherence

- `/specs/design/` is the UI source of truth. Read the relevant board section **before**
  building or altering any screen; match spacing, radii, colors, type, motion exactly.
- If a screen or state is not covered by the spec, **stop and ask**. Never invent UI.
  If you must stub, leave `// TODO(design):` and a neutral placeholder.
- Everything visual resolves through design tokens (`core/theme/`). No raw hex, no magic
  numbers for size/radius/duration in feature code.

## Performance — DO

- `const` constructors aggressively; prefer `StatelessWidget`; keep `build` cheap.
- Long lists → `ListView.builder` / slivers. Never a giant `Column` of items.
- Paginate DB queries. Search goes through FTS5. Debounce search input (~250ms).
- Wrap independently-animating or expensive subtrees in `RepaintBoundary`.
- Build `ThemeData` **once per theme** and cache it; never recompute per build.
- Granular providers + `select` so a change rebuilds the smallest possible subtree.
- Dispose every controller, timer, and subscription.
- Cache images/favicons via `cached_network_image` with `memCacheWidth`/`memCacheHeight`.
  Cache fetched metadata in the DB so it works offline and refetch is rare.
- Heavy work (HTML parsing, import/export) runs off the UI isolate via `compute`.
- Animations: 150–260ms, spring for finger-caused, emphasized-decelerate for
  system-caused. Honour reduced motion (`MediaQuery.disableAnimations` /
  `accessibleNavigation`): transforms → 90ms fades, springs → linear 120ms.

## Performance — DON'T

- No `BackdropFilter`/blur except behind the explicit Appearance toggle (off by default).
  It is the only real GPU cost in the app.
- No network or heavy compute on the UI isolate. No unbounded lists.
- No `setState` rebuilding a large subtree — localise state.
- No hardcoded colors, sizes, radii, or durations in feature code.

## Modularity

- Feature-first: `lib/features/<feature>/`; shared UI in `lib/shared/widgets/`;
  infrastructure in `lib/core/`.
- Repository/service layer sits over Drift. **No business logic in widgets.**
- Reuse the shared widgets. If two elements share a layout or background, they share a
  widget. Do not duplicate. Each of these has exactly one implementation:

| Need | Use |
|---|---|
| Screen top bar | `AppHeader` — title + optional back + trailing actions |
| Any icon action (back, search, share, overflow, edit, view switcher, close) | `AppIconButton` |
| Anchored menu (view switcher, long-press, overflow) | `showAppMenu` + `AppMenuEntry` |
| Bottom sheet (incl. full-height with sticky header/footer) | `showAppBottomSheet(expand: true)` |
| Single choice in a sheet | `showOptionSheet` |
| Button | `AppButton` |
| Text field in a labelled box | `LabelledField` + `PlainTextField` |
| Colour choice | `ColorSwatchRow` |
| Tag chip (10.5px card form, pill form, dashed add) | `TagChip` |
| Choosing tags | `showTagPicker` |
| Choosing a folder | `showFolderPicker` |
| Creating a folder or tag inline | `NewFolderRow` |
| Toast / confirmation | `AppSnackbar` (info · success · warning · error) |
| Dashed outline | `DashedBorderPainter` |
| `LABEL · 128` + sort row | `SectionHeader` |
| Link list, incl. pinned section and selection | `LinkList` |
| Quick actions on a link | `showLinkQuickMenu` / `runLinkAction` |

- **Add and Edit are one route** (`/link/edit`, optional `?id=`). There is no separate
  edit screen and no separate note editor.
- Small files; one widget per file where reasonable; clear names.

## Colour

- Tag and folder colours are stored as an **index into `PerchColors.tagHues`**, never as
  an ARGB value, so they re-derive per theme and stay legible in light, dark and AMOLED.
  Resolve with `context.colors.tagColor(index)` / `folderTint(index)`.
- The snackbar's four variants resolve through `context.colors.snack(variant)`.

## Data

- **Dev phase:** a schema change bumps `schemaVersion` and `onUpgrade` drops and
  recreates the database. Before release this becomes a real migration path — every
  schema change will then need a written migration **and** a migration test.
- Import/export must round-trip losslessly (folders as a parentId tree, links with tags
  and markdown note inline).

## Privacy

- INTERNET is the only permission. No telemetry, no analytics, no ad SDKs — ever.
- Metadata is fetched directly from the saved link, on device. Nothing is proxied.

## Quality

- `flutter analyze` stays clean. Strict lints are on and warnings are real.
- Tests for repositories/services (folder nesting, tag joins, import/export round-trip,
  URL extraction) and for shared widgets. Golden tests for design-critical components.
- Accessibility: semantic labels on controls, 48dp min tap targets, respect OS text
  scale and reduced motion, AA contrast in every theme including AMOLED.
- Never crash on a metadata fetch error — fall down the preview ladder
  (`og:image` → favicon → monogram tile).

## Simplicity guard

If a dependency or abstraction is not clearly earning its place, don't add it.
