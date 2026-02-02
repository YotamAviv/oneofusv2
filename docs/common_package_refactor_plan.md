# Plan to Refactor oneofus_common Package for Merge

This document outlines the steps to prepare the `oneofusv22` project for merging its copy of the `oneofus_common` package with the version in `nerdster13`. The goal is to align the `oneofusv22` structure with the `nerdster13` "v2" structure, minimize disruption, and eventually use a single shared package.

## Phase 1: Clean up `util.dart`

The `util.dart` file in `oneofus_common` has been split up in the `nerdster13` version. We will emulate this change in `oneofusv22`.

### Steps:

1.  **Inline simple helpers:**
    *   Replace all usages of `b(dynamic d)` and `bb(bool? bb)` in `oneofusv22/lib` with inline null checks.
    *   Example: `if (b(x))` becomes `if (x != null)`.

2.  **Move Clock and Date Parsing:**
    *   Create `packages/oneofus_common/lib/clock.dart` (matching `nerdster13`).
    *   Move `Clock`, `LiveClock`, `clock` (global), `formatIso`, and `parseIso` from `util.dart` to `clock.dart`.

3.  **Move UI and App-Specific Helpers:**
    *   The functions `isPubKey`, `formatUiDatetime`, and `datetimeFormat` are not present in the `nerdster13` common package. They should be moved to the application code.
    *   Create/Update `oneofusv22/lib/util.dart` (or similar app-level utility file) and move these functions there.

4.  **Delete `packages/oneofus_common/lib/util.dart`:**
    *   Once empty, remove the file.

5.  **Fix Imports:**
    *   Update all imports in `oneofusv22/lib` that referenced `package:oneofus_common/util.dart` to point to the new locations (`package:oneofus_common/clock.dart` or the app-level `util.dart`).

## Phase 2: Remove dependency on `SettingType`

The `nerdster13` version of `oneofus_common` does not contain `SettingType`. It defines `SettingType` in the application code.

### Steps:

1.  **Remove Factory:**
    *   Remove `factory Setting.fromType(SettingType type)` from `packages/oneofus_common/lib/setting.dart`.
    *   Remove `import 'package:oneofus_common/setting_type.dart';` from `setting.dart`.

2.  **Delete `SettingType` Definition:**
    *   Delete `packages/oneofus_common/lib/setting_type.dart`.

3.  **Handle Usage (if any):**
    *   Current analysis suggests `SettingType` is not used in `oneofusv22` application code. If usages are found, move `SettingType` enum to `oneofusv22/lib` and update imports.

## Phase 3: Future Consolidation (Next Steps)

After Phase 1 and 2, the `oneofusv22` common package will be closer to `nerdster13`'s version. The next steps would be:

1.  **Split `io.dart`:** Refactor `io.dart` in `oneofusv22` into `statement_source.dart` and `statement_writer.dart`.
2.  **Move Crypto:** Move `crypto.dart` and `crypto25519.dart` to `lib/crypto/`.

Pause here

4.  **Hard Swap:** Replace `oneofusv22/packages/oneofus_common` with the `nerdster13` version and fix any remaining broken imports.
