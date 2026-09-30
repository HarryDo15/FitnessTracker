import Foundation

@MainActor
enum HaiBaselineValues {
    private static let plates = "Enter plates on ONE side only. Exclude the bar and machine weight."
    private static let dumbbells = "Enter weight per dumbbell."

    // Notebook barbell/Smith values are per side unless explicitly stated otherwise.
    // 1p = 20 kg per side. Partials and uncertain notebook annotations stay in notes.
    static var entries: [BaselineWorkoutSeed.Entry] {
        let values: [(sets: [(Double, Int)], notes: String, load: String)] = [
            ([(12, 12)], "", dumbbells),
            ([(7.5, 12)], "Used the first notebook alternative: 7.5 × 12. Unlogged alternative: 10 × 11.", ""),
            ([(17.5, 11)], "Notebook marks 17.5 × 11 as uncertain (?). Cable setting was not recorded.", ""),
            ([(5, 13)], "", "Single arm; cable set below 31."),
            ([(60, 10)], "", ""),
            ([(50, 10)], "", ""),
            ([(50, 8), (60, 4)], "25 kg per side × 8; 30 kg per side × 4.", "Enter total plates on both sides, excluding the bar weight."),
            ([(20, 10)], "", "Single arm; enter the cable stack weight."),
            ([(85, 10)], "", ""),
            ([(30, 6)], "30 kg per side; 6 full reps plus 1 partial rep (notebook: 6.5). No chest support.", plates),
            ([(2.5, 12)], "", ""),
            ([(26, 9)], "Notebook: bench press at 50 degrees.", dumbbells + " Bench angle: 50 degrees."),
            ([(5, 12), (7.5, 6)], "", ""),
            ([(30, 9)], "Used the first notebook alternative: 30 kg per side × 9 (!). Unlogged alternative: 35 kg per side × 5.", plates),
            ([(26, 9)], "", dumbbells),
            ([(15, 8), (30, 10), (35, 8)], "15 kg per side × 8, slow; 30 kg per side × 10 (!); 35 kg per side × 8 (!).", plates),
            ([(12.5, 10)], "", "Cable set above 25."),
            ([(20, 8)], "20 kg of plates on each side; bar excluded.", plates),
            ([(40, 9)], "2p: two 20 kg plates per side (40 kg per side).", plates),
            ([(60, 5)], "3p: three 20 kg plates per side (60 kg per side).", plates),
            ([(30, 12)], "1p10: 20 + 10 kg per side (30 kg per side).", plates)
        ]
        precondition(values.count == HaiExerciseLibrary.entries.count)
        return zip(HaiExerciseLibrary.entries, values).map { exercise, value in
            BaselineWorkoutSeed.Entry(name: exercise.name, aliases: exercise.aliases,
                muscle: exercise.muscle, equipment: exercise.equipment, sets: value.sets,
                notes: value.notes, loadNotes: value.load)
        }
    }
}
