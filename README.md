# FitnessTracker

Native SwiftUI + SwiftData fitness tracker for iOS 17+. Two local profiles, workout logging, progressive overload, Swift Charts, shared gym visits, and punch-card rewards. No third-party dependencies or cloud account required.

## Understanding the code

- [Architecture and code walkthrough](docs/ARCHITECTURE.md): targets, startup, navigation, model relationships, state ownership, saves, and a set-logging sequence diagram.
- [Complete feature reference](docs/FEATURES.md): screen entry points, source links, formulas, validation, and edge cases for every implemented feature.
- [Maintenance and testing](docs/MAINTENANCE.md): reading order, where to change rules, seed/migration behavior, backup compatibility, test coverage, and troubleshooting.

Start with Architecture, then use the feature reference alongside the Swift files. Gym check-ins and workouts are separate records: a workout in History does not automatically appear in All gym visits.

## Open and run

Prerequisites: a Mac with **full Xcode 27 or later for the included project** (the package uses iOS 17 APIs), its iOS Simulator runtime, and an iOS 17+ Simulator or device. Command Line Tools alone do not include the SwiftData/SwiftUI compiler plugins needed for this app. The Swift package uses Swift 5 language mode and also targets macOS 14+ for tests.

The repository includes the Swift package and a ready-to-open iOS app project.

1. Open **`iOSApp/FitnessTrackerIOS.xcodeproj`** in Xcode. The app references the package in the repository root automatically.
2. Select the **FitnessTrackerIOS** scheme and an iOS 17+ Simulator, then press **Command-R**.
3. For your iPhone, choose your development team under **Signing & Capabilities**, select the connected device, and press **Command-R**. Keep your existing bundle identifier when updating an installed app to retain local data.
4. First launch creates Hai and Qi, their exercise libraries, the September 26 baseline workouts, and Qi’s seven carried-over punches. Updates preserve existing data using one-time migrations.
5. Use the profile picker above the tabs to switch between Hai and Qi. The gear button opens rest-alert settings and backup/export.

`iOSApp/FitnessTrackerApp.swift` remains available as a standalone entry-point example if creating a different host. Add the local `FitnessTracker` library product and keep only one `@main` declaration in the host target.

For previews, open `Package.swift` in Xcode. `PreviewHost` and the gym/progress preview hosts always use in-memory data and never change the production store.

## Run tests

From the package directory, run the full XCTest suite with a full Xcode selected:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

If Xcode is installed elsewhere, substitute its actual `Contents/Developer` path. Alternatively, open `Package.swift`, select the package scheme and **My Mac**, and press **Command-U**. The macOS test destination requires macOS 14+; use an iOS Simulator from Xcode for iOS execution.

Focused test suites:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter ProgressionEngineTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PunchCardRulesTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GymVisitTests
```

When only Command Line Tools are available, the dependency-free rule harness still compiles and executes the real progression, input-validation, timer, and punch-card rule sources:

```sh
bash scripts/check-workout-math.sh
```

**Validation (September 30, 2026):** Full Xcode package build and all 52 macOS XCTest tests passed, including SwiftData integration, exercise creation/editing, photo persistence, starting references, and punch-card carryover. The iOS app and embedded Live Activity extension also build successfully. Physical-device photo picking, haptics, Live Activity presentation, and visual/VoiceOver checks remain pending.

If the app cannot open its data store, it now shows the error with **Try again** instead of crashing or silently replacing the store. The app uses local persistence only. Simulator and device installations have separate stores; there is no synchronization between phones.

## Accessibility and appearance checks

- UI text uses Dynamic Type. Headers, metrics, number controls, the rest timer, and punch slots reflow at accessibility sizes; workout start and celebration screens scroll. There is no forced light/dark appearance in the running app.
- Text uses semantic foreground/background styles. Progress states include words and distinct symbols instead of depending on color. White punch stamps use a dark raspberry fill; increased contrast strengthens empty-slot outlines.
- VoiceOver reads the selected profile, completed set values with explicit units/repetitions, timer duration, punch state, and contextual logging controls. Number fields support adjustable actions, decorative graphics are hidden, and check-in results are announced. Charts have names/units and a readable session-data alternative.
- Reduce Motion suppresses stamp movement and confetti. Confetti also stops after five seconds normally. The congratulations heading receives accessibility focus.
- Added dark-mode/largest-text previews for workouts, charts, the punch card, and the celebration. In Simulator, inspect these on a small phone and in landscape, with the largest accessibility text size and Increased Contrast. Confirm all buttons remain reachable by scrolling.
- On an iPhone, enable VoiceOver and walk through start → add exercise → log set → timer → finish, then shared check-in → tenth punch → claim. Verify labels, focus order, spoken result messages, and haptics. These device checks remain pending in this environment.

## Data behavior

- First launch creates “Hai” and “Qi” with separate exercise libraries. Profile names are editable model values.
- Library seeding is versioned per profile and saves once; launch does not restore exercises the user deleted or overwrite customizations.
- Profile selection is stored in UserDefaults. The root picker stays above every tab/navigation stack; future modal screens can embed the reusable `ProfilePicker` and inherit `ProfileContext`.
- Workout history and exercises use queries scoped to the active profile ID. Gym visits and rewards are shared so either person can check in together and view the girlfriend’s card. Switching profiles resets navigation state.
- Session deletion cascades to exercise logs and sets. Profile deletion cascades to owned records. Exercise deletion preserves log snapshots; prefer setting `isArchived` for exercises with history.
- Logs snapshot exercise name, weight unit, and assistance semantics, so library edits do not reinterpret previous sets. Set weights use their log’s unit. Assisted pull-up weight means assistance, where less assistance is progression.
- Set completion is represented by `completedAt`; nil means planned. RPE is optional and accepts 1–10 including fractional values.
- Relationship constructors reject mixing profiles, and set constructors validate input. SwiftData properties remain mutable: future editing actions must apply the same validation before saving or changing ownership.
- Gym visits, punch cards, and rewards persist locally. Gym check-ins and reward claims are implemented; sets in completed workouts can be edited or deleted from History.
- Preview data uses a fresh in-memory store with both profiles, sample workouts, completed sets, visits, cards, and rewards. It never writes to the production store or profile preference.

`ProfileContext` manages selection; `WorkoutViewModel` handles workout actions, validation, prefills, and saves. SwiftData `@Query` powers read-only screens directly.

## Workout logging

- Today → Start Workout creates a session for the selected profile. Returning to Today or reopening the app resumes that profile’s unfinished session; switching profiles keeps sessions separate.
- Add Exercises opens the profile’s library with large rows and optional search. Add multiple exercises, then tap Done at the bottom. Already-added exercises are marked and cannot be duplicated.
- Each exercise shows its last completed workout’s working sets. Set 1 starts with the previous Set 1 values, Set 2 with previous Set 2, and so on. Additional sets reuse the latest set logged today. Exercises with saved starting references use those values until completed workout history is available; other new exercises start at zero weight and the lower target rep count. Unit changes are converted for prefilling while “last time” retains its original units.
- Weight and rep controls use 56-point plus/minus buttons; the values also accept direct numeric entry. Log Set saves immediately and starts a 3-minute rest timer. Subsequent sets restart the timer. +30s and Skip are always available at the bottom.
- The timer stores an absolute deadline in the session, so backgrounding, tab changes, profile switches, and relaunching do not reset elapsed time. It displays “Ready for your next set” at zero. Optional local notifications announce rest completion while locked; enable them using the gear button → Notify when rest ends.
- Finish Workout becomes available after the first completed set. It saves the finish time and shows completed set count, exercise count, duration, and weight × reps volume. Planned sets are excluded; kg and lb totals remain separate. Assistance weight is excluded from volume because it is not lifted load.
- Previews include an active workout, the rest timer, and a completed-workout summary. The active preview uses an isolated in-memory store.

Workout-flow integration tests cover start/resume, profile isolation, prior-set prefills and unit conversion, first-exercise defaults, discarding empty workouts, set logging, rest controls, finish, and mixed-unit/assisted-volume summaries. Input bounds (0–10,000 weight and 1–999 completed reps) prevent invalid values and stepper arithmetic overflow. Planned sets may have zero reps. Empty workouts can be discarded; workouts with completed sets cannot.

## Progressive overload

- Exercise cards compare logged working sets against the previous completed session and show a target with a **Use target** button. During a workout, improvements show immediately; matched/regressed results wait until finishing so a partial workout is not mistaken for a regression. The finish summary includes final comparisons and targets for next time.
- Open **Exercises → an exercise** for Swift Charts of estimated 1RM and total volume, session data, and next-workout targets. The settings button edits the rep range and weight increment. New logs snapshot these settings; changing them does not alter an existing workout. Existing stores receive an 8–12 default range.
- **Progress** lists exercises with at least three consecutive completed comparisons without improvement (four sessions minimum). Active/empty sessions and warm-ups do not affect the dashboard. Every history lookup stays scoped to the selected profile and exercise.
- Rules live in the short comment block in `Sources/FitnessTracker/Features/Progress/ProgressionEngine.swift`. Improvements use an OR rule: higher peak load, more reps at a shared weight, or greater total volume. Improvements win when measures disagree. Double progression increases weight only after all working sets reach the rep ceiling, then resets reps to the floor; otherwise it adds a rep to sets below the ceiling.
- History weights are normalized to the exercise’s current unit. Estimated 1RM uses the best working set’s Epley estimate, `weight × (1 + reps / 30)` (singles use the actual weight). This estimates performance, not a measured max. Formula reference: [Effects of Complex Training… (2023), methods](https://publications.cuni.cz/bitstream/handle/20.500.14178/2075/sports-11-00181.pdf?isAllowed=y&sequence=1).
- Assisted exercises reverse the load rule: less assistance is progress. Their charts show assistance and reps instead of estimated 1RM/volume, which cannot represent lifted load without body weight. Assistance targets never go below zero.
- In-memory previews include a six-session chart and a stalled exercise. Additional SwiftData tests cover settings snapshots, profile filtering, warm-ups/planned sets, unit conversion, and merging repeated logs into one session point.

## Shared gym visits and punch cards

- **Rewards → Check in at gym** supports “Both of us” or either person, with a date picker for today or a past day. Joint check-ins insert only people who are missing for that day and report who was already checked in. They never change workout ownership.
- Duplicate prevention uses a persisted, unique profile + Gregorian local-date key plus a pre-insert check. Day keys are stable after time-zone changes; legacy visits without keys are checked by local date. Check-in actions run synchronously on the main actor and save once, rolling back on failure. Midnight and daylight-saving changes use calendar days, not a rolling 24-hour interval.
- The girlfriend’s profile has `punchCardEnabled` set once during seed migration, using the original seed name/symbol. Later profile renames preserve this setting. The other profile records visits without earning punches. New cards have exactly ten slots.
- Each credited visit animates a stamp and triggers an iOS impact haptic after saving. The tenth punch opens a full-screen congratulations view with native Canvas confetti, a success haptic, the reward message, and **Claim reward**. Reduce Motion disables confetti and stamp motion. On macOS the celebration uses a sheet and haptics are omitted.
- The gear beside the punch card opens **Reward settings**. Default text is “You earned a treat!” (editable, 1–200 characters). Edits update the open, unearned card and future cards. Earned and claimed rewards retain their original message.
- Claiming saves the redemption date, archives the full card, and creates a fresh card in one save. Repeat claims do nothing. Visits logged while a full card awaits claiming are queued, then credited to the fresh card on claim; no visits are lost and cards never overflow. Without queued visits, the new card starts at zero. **Later** leaves the earned reward available to claim.
- **Past punch cards** retains completed cards, reward messages, claim dates, and their visits. **All gym visits** lists both profiles’ visits, including queued punches. Reopening the Rewards tab after relaunch restores any unclaimed reward.
- Added previews for nine punches and the tenth-punch celebration. SwiftData integration tests cover joint/single check-ins, partial duplicates, the tenth punch, overflow queueing, empty rollover, repeat claims, reward-message snapshots, relaunch reads, invalid input, and legacy visits. These tests pass with full Xcode selected. Physical-device haptics and visual animation QA still require an iPhone.


## Exercise photos and personal starting values

- **Exercises → Add exercise** creates an exercise for the selected profile. You can also choose **Create exercise** while adding exercises to a workout. Open an exercise and tap **Edit** to change its name, equipment, muscle group, units, assistance setting, or load notes.
- In the editor, **Add photo** opens the native photo picker. Photos appear in exercise details and during set logging. You can replace or remove them. Images are resized to at most 1,200 pixels and saved locally as JPEG data using SwiftData external storage; no broad photo-library permission is needed.
- Qi receives 13 starting references once, including hip thrusts. Bulgarian split squats use **5 kg per dumbbell × 10**; Smith squats use **2.5 kg per side × 10** and hip thrusts **15 kg per side × 12**, excluding bar/machine weight. These values are imported once as a completed baseline workout dated 26 September 2026, with one supplied set per exercise. They appear in History, charts, and last-session prefills. Known partial reps are stored separately (hamstring curl: 8 full + 3 partial; leg extension: 9 full + 1 partial), with the original notes retained. Partials do not inflate full-rep totals.
- Qi’s current card imports enough previously earned punches to reach **7/10** once, preserving existing visits and any progress above seven. Unknown visit dates are not fabricated. The next three distinct check-ins complete a seven-punch card; claiming starts a fresh card without repeating the import.
- Rebuild and run the existing app on your phone to apply these additions. Keep the existing installation and bundle identifier to retain its local data. Generic previews opt out of personal imports.

## App icon and profile name

The existing iOS host includes the dumbbell app icon in `Assets.xcassets/AppIcon.appiconset`. A portable copy is in `iOSApp/Assets.xcassets`; for a new host, copy its AppIcon set into the host asset catalog and select `AppIcon` as the app icon source. Generation mode and the full prompt are recorded in `iOSApp/AppIcon-Prompt.txt`.

On the next launch, the original “Me” profile is renamed to “Hai” once without replacing its ID or history. Custom names are preserved. To find Qi’s initial values, choose **Qi → Exercises → an exercise → Starting reference**. They prefill workout sets. Qi’s dated baseline is also available under **Qi → History → 26 September 2026**, and supplies the first chart point.

Baseline imports preserve notebook notes in History, do not create gym visits, and never repeat after launch or deletion. Their date is known but time and duration are not; History omits an invented completion time.


Hai’s baseline is also imported once on **26 September 2026**: 21 exercises and 25 supplied sets, visible under **Hai → History** and used by charts and next-workout prefills. Dumbbell loads are per hand. Smith weights are recorded per side, excluding the bar: `2p = 40 kg`, `3p = 60 kg`, and `1p10 = 30 kg` per side. The non-Smith barbell chest-supported row retains total-plates recording. Hai’s Smith Bulgarian split squat is 20 kg per side × 8 reps, excluding the bar. Existing imported baselines are corrected once, including installations that already applied the earlier per-side migration. Bayesian curls and Smith flat bench use only the first “or” alternative; the other value is retained as an unlogged note. The Smith row’s 6.5 reps means 6 full plus 1 partial; the overhead extension’s uncertainty and machine settings remain visible in History notes. No gym visits or extra punches are created by either baseline import.

## Profile avatars

Open the profile switcher → **Edit profile photos** → **Hai** or **Qi** → **Add photo**, then **Save photo**. The active profile’s avatar appears beside its name in the switcher. The same screen replaces or removes a photo; Cancel or navigating back discards unsaved edits. Photos use the native picker, are resized and stored locally in SwiftData, and do not require full photo-library permission. Profiles without a photo keep their default symbol. Physical-device photo selection still needs manual verification.

A one-time load correction updates existing Smith total-plates logs to per-side weights and corrects Qi’s imported hip thrust to 15 kg per side. Dates, repetitions, workout identities, and punch cards are preserved; relaunching never halves the weights a second time. Volume and 1RM calculations use the recorded per-side load, not total machine resistance.


## Faster logging and routines

- **Edit sets:** tap a logged set in Today or History. Adjust weight/reps, then Save changes. Delete set requires confirmation. History charts and progression recompute from corrected sets.
- **Undo:** Today → Undo last set returns the most recently logged set to a planned state and cancels its rest timer. Log it again with the corrected values. The undo action is available during the current logging flow.
- **Repeat last workout:** Today → Repeat last workout selects the active profile’s latest completed workout, keeps the available exercises in order, and preloads planned sets using double-progression targets. Archived/deleted exercises are skipped. Existing unfinished sessions are resumed instead of overwritten.
- **Templates:** Today → Workout templates → + creates a named Leg/Push/Pull or custom routine. Choose exercises, reorder them, and select a common count of 1–20 sets for each exercise. Edit or swipe-delete routines from the list. During a workout, Save as template copies its exercise order. Templates belong to one profile; starting one uses current progression targets and never marks planned sets complete.
- **Favorites and setup:** Exercises → an exercise → Edit → Favorite / Setup notes. Favorites sort first in the library and Add Exercises; Favorites only and search narrow the library. Seat/cable/bench notes appear in exercise details and while logging.
- **Rest alerts:** gear → Notify when rest ends prompts for iOS notification permission. Logging restarts the 3-minute alert; +30s reschedules it, and Skip, Undo, Finish, or discarding the workout cancels it. Both profiles’ timers remain independent. Focus or device notification settings can silence delivery. Check actual locked-screen behavior on an iPhone.

## Backup, export, and restore

Use **gear → Save full backup** to save a versioned JSON document in Files, including both profiles, avatars, exercise photos, library settings/favorites, snapshots and sets, templates, gym visits, cards, rewards, and seed-migration markers. **Export sets as CSV** creates a readable table; it is not a restorable backup. Files contain personal data and are not encrypted by the app.

**Restore full backup** validates the JSON in a separate in-memory store before asking to replace local data. Replacement happens in a single SwiftData save with rollback on failure. Corrupt files, invalid relationships, unsupported versions, files over 100 MB, and more than 100,000 records are rejected. Save a current backup before replacing local data if you want to retain it. Rest alerts turn off after restore; turn them back on in Settings if desired. Backup files and device databases are excluded from Git.

Validation includes repeat/undo behavior, template ownership and ordering, invalid set edits, favorites persistence, complete backup round trips (including deleted exercise snapshots, photos, visits, and claimed rewards), and rejection of invalid archives without changing the live store. Notification delivery, file-picker interactions, and VoiceOver should also be checked on a physical iPhone.


## Train together, substitutions, and partial reps

- **Today → Train together** starts or resumes one session per profile on the same phone. Choose a shared exercise, then log a set; the next person’s turn appears automatically. Each profile keeps its own load, history, rest deadline, and undo action. Both rest timers remain visible. Matching uses exercise names, never the other person’s weights. If a matching exercise is missing, choose that person’s alternative explicitly. Closing the screen leaves workouts active; Finish both saves completed sets and discards empty sessions.
- **Swap exercise** on a logging card replaces uncompleted work with an exercise from that profile’s library, sorted with the same muscle group first. Already completed sets remain attached to the original exercise. Replacement targets come from the replacement’s history, with a starting reference or zero-load fallback for a first workout.
- **Partial reps** has its own stepper when logging or editing a set. Last-time values and History show both full and partial reps. Only full reps affect volume, progression, estimated 1RM, and personal records. Previously supplied baseline partials are imported once: Qi’s hamstring curl +3, leg extension +1, and Hai’s Smith row +1. Later edits are preserved.
- **Personal records** show a trophy banner and success haptic when a logged working set beats the exercise’s earlier weight, reps at that weight, or estimated 1RM. First-ever sets establish a baseline. Assisted exercises celebrate less assistance and full-rep improvements, without an estimated-1RM record.
- **Reorder exercises** during a workout opens a drag-to-reorder list. Saving changes the order without replacing logs or sets.
- **Progress → Weekly consistency** shows Monday–Sunday training days, completed workout count, and muscle groups for each profile. Multiple workouts on one date count as one training day. Imported baselines count; unfinished workouts and warm-up-only sessions do not. New logs snapshot muscle groups so later library edits do not rewrite weekly history.

## Live Activity

Enable **gear → Show Live Activity**, then log a set. The Lock Screen shows the profile, exercise, rest countdown, and next set. Dynamic Island is supported on compatible iPhones. Rest extension/skip updates the activity; finishing or discarding ends it. Each session has a separate activity, so both profiles can train together. Backups restore data but end existing activities. iPhone system settings may disable Live Activities, and iOS controls their delivery and lifetime.

The included app embeds the `WorkoutLiveActivity` WidgetKit extension and sets `NSSupportsLiveActivities`. The tiny `WorkoutActivitySupport` package product shares ActivityKit attributes between the app and widget without linking the fitness database into the widget. Both the app and extension need the same development team for device signing. The existing app project under `Projects/iOS/FitnessTrackerIOS` has also been updated locally.

New backups use JSON version 2 to include partial reps and muscle snapshots. Version 1 backups remain readable; missing partials default to zero, with the known baseline annotations migrated on startup. CSV exports have separate Full reps and Partial reps columns. No iCloud synchronization is implemented.
