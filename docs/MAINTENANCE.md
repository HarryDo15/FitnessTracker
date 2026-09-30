# Maintaining and testing the app

Read [Architecture](ARCHITECTURE.md) for the data flow and [Features](FEATURES.md) for current rules. This guide maps common changes to their implementation and tests.

## Suggested reading order

1. [App entry point](../iOSApp/FitnessTrackerIOS/FitnessTrackerIOSApp.swift), [container factory](../Sources/FitnessTracker/Persistence/ModelContainerFactory.swift), and [root tabs](../Sources/FitnessTracker/App/RootTabView.swift): how dependencies reach the screens.
2. [Models](../Sources/FitnessTracker/Models): ownership, snapshots, and completion state.
3. [WorkoutViewModel](../Sources/FitnessTracker/Features/Workout/WorkoutViewModel.swift): trace `start`, `draft`, `logSet`, and `finish`.
4. [ExerciseProgress](../Sources/FitnessTracker/Features/Progress/ExerciseProgress.swift) then [ProgressionEngine](../Sources/FitnessTracker/Features/Progress/ProgressionEngine.swift): record filtering versus pure math.
5. [GymVisitService](../Sources/FitnessTracker/Features/Gym/GymVisitService.swift): check-in/claim transactions and queueing.
6. [BackupService](../Sources/FitnessTracker/Features/Backup/BackupService.swift): reconstruction and validation of the entire graph.

## Where to change a behavior

| Desired change | Start here | Also inspect |
| --- | --- | --- |
| Progressed/matched/regressed rules | `ProgressionEngine.compare` / `improvement` | ProgressionEngineTests; feature docs |
| Next target or stall threshold | `ProgressionEngine.targets` / `stalledSessionThreshold` | ExerciseProgress required counts; repeat/template planning |
| Rest duration | `WorkoutViewModel.logSet` currently adds 180 seconds | Settings copy, README, timer/notification tests; it is not yet a user-configurable preference |
| kg/lb conversion | `WorkoutCalculations.convertedWeight` | Editor increment conversion, prefill, charts, records |
| Summary totals | `WorkoutSummary` | Its warm-up behavior differs from progression |
| Personal-record policy | `PersonalRecords.achievements` | GymCompanionTests; current-session records |
| Number of punches | `GymVisitRules.punchesPerCard` | Service card title, celebration/error copy, existing card goals, tests; existing cards store their own goal |
| Reward text | In-app Reward settings | Message snapshots are preserved once earned |
| Baseline content/correction | Persistence seed files | Version markers, migration tests, backup record fields |
| New persistent field | SwiftData model | Constructor defaults, backup export/apply, validation, preview/test fixtures, migration compatibility |
| New screen | Feature folder + root/navigation entry | Ownership filters, accessible labels, empty/error states |
| Live Activity appearance/data | Widget + WorkoutActivitySupport | Coordinator, embedding, signing, physical iPhone testing |

Source paths above are under `Sources/FitnessTracker` unless a separate target is named. Use `rg 'symbolName' Sources Tests` to locate all callers before changing a rule.

## Seed and correction lifecycle

[SeedData.install](../Sources/FitnessTracker/Persistence/SeedData.swift) runs on store startup, but each personalized operation is guarded by per-profile versions. The current order matters:

1. Create default profiles only if none exist; establish reward eligibility and common libraries.
2. Apply `PerSideLoadCorrection` to existing data before installing the corrected new seeds.
3. Rename the old default Me profile to Hai once, preserving custom names.
4. Install Qi starting values/name and Hai's additional exercise library.
5. Import the September 26 baselines once.
6. Import known baseline partial-rep counts once.
7. Bring Qi's initial punch progress to at least seven once, preserving higher progress.
8. Save the changes.

Relevant sources: [QiStartingValues](../Sources/FitnessTracker/Persistence/QiStartingValues.swift), [HaiExerciseLibrary](../Sources/FitnessTracker/Persistence/HaiExerciseLibrary.swift), [HaiBaselineValues](../Sources/FitnessTracker/Persistence/HaiBaselineValues.swift), [BaselineWorkoutSeed](../Sources/FitnessTracker/Persistence/BaselineWorkoutSeed.swift), [PerSideLoadCorrection](../Sources/FitnessTracker/Persistence/PerSideLoadCorrection.swift), [PartialRepSeed](../Sources/FitnessTracker/Persistence/PartialRepSeed.swift).

Changing a seed constant alone does **not** update devices whose version marker is already current. Add a narrowly scoped new migration version when an existing installation needs a correction. Preserve record IDs, dates, ownership, and user edits outside the intended correction. Test both fresh installs and upgrades, then run the installer twice to prove it does not repeat. Never reset a marker simply to force sample data back into a user's store.

`includePersonalValues: false` skips personal imports for generic fixtures. Preview containers are memory-only. Baseline imports do not produce `GymVisit` records. Carried-over punches have no fabricated visit dates.

## Adding a persistent property safely

First decide whether the value describes the current exercise, historical log, set, or UI preference. For example, a historical load convention belongs in the log snapshot as well as the exercise; temporary text-field contents belong in a view model.

Update the model/initializer and all relevant snapshot constructors. Add the field to its Codable backup record, export initializer, and apply method. For compatibility with older JSON, make newly introduced fields optional in the record and supply a sensible restore default, or explicitly version/reject the old format. SwiftData store migration and JSON archive migration are separate concerns.

Validate new input before mutating saved objects. Add a meaningful round-trip/upgrade test, including invalid input that must leave the live store unchanged. Changes to relationships or incompatible types need migration planning; the project currently has no explicit versioned SwiftData schema plan.

## Automated test map

All test files are in [Tests/FitnessTrackerTests](../Tests/FitnessTrackerTests).

| Suite | What it protects |
| --- | --- |
| `PersistenceTests` | Independent libraries, validation, snapshots, cascade deletion, profile selection |
| `WorkoutFlowTests` | Start/resume, prefill/conversion, timer, finish, first-workout defaults, summaries |
| `ProgressionEngineTests` | Mixed-metric comparisons, double progression, assisted lifts, stalls, bounds, chart math |
| `ExerciseProgressTests` | Settings snapshots, history filtering/grouping, units, shortened-session target safeguards |
| `PunchCardRulesTests` | Unique dates, ten-punch boundary, queue slots, carried-over punches |
| `GymVisitTests` | Joint/single duplicates, claim/rollover, reward snapshots, legacy visits, invalid actions |
| `PersonalizationTests` | Baselines, references, first alternatives, idempotency, seven-punch seed |
| `PerSideLoadCorrectionTests` | One-time conversions and Bulgarian correction upgrades |
| `ExerciseEditorTests` / `ProfileAvatarTests` | Profile isolation, edits, duplicate names, photo preparation/persistence/removal |
| `UsabilityTests` | Repeat, undo, templates, corrected history, favorites/setup notes |
| `GymCompanionTests` | Together ownership/turns, alternatives, substitutions/order, partials, PRs, weekly metrics |
| `BackupTests` | Full graph round trip, version 1 support, invalid restore isolation, CSV escaping |

Run from the repository root with full Xcode installed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter ProgressionEngineTests
```

Build both app and embedded widget without device signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project iOSApp/FitnessTrackerIOS.xcodeproj \
  -scheme FitnessTrackerIOS -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/fitness-tracker-docs-build \
  CODE_SIGNING_ALLOWED=NO build
```

With only Command Line Tools, `bash scripts/check-workout-math.sh` checks selected pure rules. It is not a replacement for SwiftData integration tests or an iOS build. The last feature implementation validation on September 30, 2026 passed 52 XCTest tests and the app/widget build. Documentation-only edits do not imply another build was run.

## Manual checks on an iPhone

These behaviors are not established by the macOS test suite:

- Run a complete solo workout and Train Together, switch profiles, background/reopen, and confirm separate prefills/timers.
- Lock the phone during rest. Check notification opt-in/denial, reschedule/skip, Live Activity updates, and Dynamic Island where supported.
- Pick/replace/remove an exercise photo and both avatars; cancel an unsaved edit.
- Save JSON through Files, restore on a disposable test installation, and check images, history, cards, templates, and profile selection.
- Use largest accessibility text, VoiceOver, dark mode, Increased Contrast, and Reduce Motion; check small-screen scrolling and the tenth-punch celebration.

Physical-device haptics, system pickers, notification/Live Activity presentation, and visual/accessibility QA were still pending after the automated feature checks.

## Troubleshooting common misunderstandings

| Symptom | What to inspect |
| --- | --- |
| Workout exists but All gym visits is empty | History reads `WorkoutSession`; visits read `GymVisit`. Use Rewards → date → Check in at gym. Baselines do not create visits. |
| Qi shows 7 punches but no dated visits | Imported progress is `carriedOverPunches`, deliberately separate from known visit dates. |
| A gym date is absent after using Check in at gym | Check the save-result/error message, the selected people/date, and that this is the same installation/store. The visit list queries all profiles, with no workout-status/date filter. |
| Next target does not increase weight | Check every working set reaches the ceiling, prior required set count is met, and no planned working sets remain. |
| Three workouts are not marked stalled | Three non-progress comparisons require at least four completed sessions. |
| Edited library settings do not change an active workout | Log settings were snapshotted when the exercise was added. |
| Weight appears half of a barbell total | Smith entries intentionally store one side excluding the bar; formulas use that recorded load. |
| Undo disappeared after reopening | The last-logged set ID is transient. Edit the saved set directly instead. |
| Phone and Simulator show different data | Each installation has its own local database; there is no sync. |
| New seed values do not appear on an existing phone | Inspect the profile's migration versions; changing constants does not rerun completed imports. |

For the September 26 visit specifically, manually checking in Qi credits a new punch. If that day is already represented among the seven carried-over punches, adding it blindly can double-count attendance. The current UI does not offer converting a carried-over punch into a dated visit; that requires an explicit reconciliation change rather than a duplicate check-in workaround.
