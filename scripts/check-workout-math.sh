#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/fitness-math.XXXXXX")"
swiftc Sources/FitnessTracker/Models/ModelTypes.swift \
  Sources/FitnessTracker/Features/Workout/WorkoutCalculations.swift \
  Sources/FitnessTracker/Features/Progress/ProgressionEngine.swift \
  Sources/FitnessTracker/Features/Gym/GymVisitRules.swift \
  scripts/ProgressionChecks.swift \
  scripts/GymRuleChecks.swift \
  scripts/WorkoutMathChecks.swift -o "$build_dir/check-workout-math"
"$build_dir/check-workout-math"
