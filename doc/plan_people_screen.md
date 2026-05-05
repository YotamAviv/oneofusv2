# Plan: People Screen & Firestore

### Phase 1: Establish Data Layer (Iterative)

**Goal**: Create a robust, working data layer before building any UI. The concrete goal of this phase is to have a function that successfully fetches the user's statements and prints them to the log.

1.  **Connect to Firestore**: Ensure the app has the necessary dependencies (`firebase_core`, `cloud_firestore`) and is correctly configured to communicate with the Firestore backend.

2.  **Migrate from `nerdster-reference`**: Move the following classes to `packages/oneofus_common/lib/`:
    *   `StatementSource` & `StatementWriter` interfaces.
    *   `CloudFunctionsSource` (for reading).
    *   `DirectFirestoreWriter` (for writing).
    *   Helper files: `distincter.dart`, `source_error.dart`.
    *   The `SettingType` enum and a minimal `Setting` class to support dependency injection.

3.  **Adapt Dependencies**:
    *   Update all imports in the migrated files to use `package:oneofus_common`.
    *   Refactor the migrated classes to accept `Setting` instances via their constructors instead of using a global `Setting.get()` method.

4.  **Create Test Function**:
    *   In a suitable location (e.g., `main.dart`'s `initState`), create a temporary function that:
        *   Instantiates `CloudFunctionsSource`.
        *   Uses it to fetch the current user's statements.
        *   Dumps the fetched statements to the debug log.

5.  **Iterate**: Debug and refine this data layer until the test function works reliably.

### Phase 2: Build People Screen UI

Once the data layer is stable, build the UI.

- **New Screen**: `lib/features/people/people_screen.dart`.
- **Functionality**:
    - Use an observable object (e.g., `ChangeNotifier`) to manage state and trigger refreshes.
    - On load and on refresh, fetch `trust` statements using the data layer.
    - Display a `ListView` of trusted people with:
        - Moniker & Comment.
        - Vouched-back status (checkbox icon).
        - Placeholder icons for Edit, Clear, and Block.
    - Include a `Refresh` icon button.

### Phase 3: Main App Integration

- **Modify**: `lib/main.dart`.
- **Startup**: Load initial data on app start.
- **Alerts**: Implement alert logic using the data layer.
- **UI**: Replace the "PEOPLE" placeholder page with the new `PeopleScreen`.
