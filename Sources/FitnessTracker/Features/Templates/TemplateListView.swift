import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    var start: ((WorkoutTemplate) -> Void)?
    @State private var creating = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if profile.templates.isEmpty {
                ContentUnavailableView("Save your routines", systemImage: "list.clipboard",
                    description: Text("Create a Leg, Push, or Pull routine. Exercises stay in your chosen order."))
            }
            ForEach(profile.templates.sorted { $0.name < $1.name }) { template in
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink { TemplateEditorView(profile: profile, template: template) } label: {
                        VStack(alignment: .leading) {
                            Text(template.name).font(.headline)
                            Text("\(template.exerciseIDs.count) exercises · \(template.setsPerExercise) sets each").font(.caption)
                        }.frame(minHeight: 44)
                    }
                    if let start {
                        Button("Start \(template.name)") { start(template); dismiss() }
                            .buttonStyle(.borderedProminent).frame(minHeight: 44)
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) {
                    context.delete(template)
                    do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
                } }
            }
        }
        .navigationTitle("Workout templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button { creating = true } label: { Label("New template", systemImage: "plus") } }
            if start != nil { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(isPresented: $creating) { NavigationStack { TemplateEditorView(profile: profile) } }
        .alert("Couldn’t save template", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
    }
}

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let template: WorkoutTemplate?
    @State private var name: String
    @State private var ids: [UUID]
    @State private var sets: Int
    @State private var errorMessage: String?

    init(profile: Profile, template: WorkoutTemplate? = nil, session: WorkoutSession? = nil) {
        self.profile = profile
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _ids = State(initialValue: template?.exerciseIDs ?? session?.orderedLogs.compactMap { $0.exercise?.id } ?? [])
        _sets = State(initialValue: template?.setsPerExercise ?? 3)
    }
    var body: some View {
        List {
            Section("Routine") {
                TextField("Name, e.g. Leg day", text: $name)
                Stepper("\(sets) sets per exercise", value: $sets, in: 1...20)
            }
            Section("Exercise order — drag to reorder") {
                ForEach(ids, id: \.self) { id in
                    HStack {
                        Text(profile.exercises.first { $0.id == id }?.name ?? "Unavailable exercise")
                        Spacer()
                        Button { ids.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Remove exercise from template").frame(minHeight: 44)
                    }
                }.onMove { ids.move(fromOffsets: $0, toOffset: $1) }
            }
            Section("Add exercises") {
                ForEach(profile.exercises.filter { !$0.isArchived && !ids.contains($0.id) }.sorted { $0.name < $1.name }) { exercise in
                    Button { ids.append(exercise.id) } label: { Label(exercise.name, systemImage: "plus").frame(minHeight: 44) }
                }
            }
        }
        .navigationTitle(template == nil ? "New template" : "Edit template")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) { EditButton() }
            #endif
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save template") {
                let saved = template ?? WorkoutTemplate(profile: profile, name: name, exerciseIDs: ids, setsPerExercise: sets)
                if template == nil { context.insert(saved) }
                saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                saved.exerciseIDs = ids
                saved.setsPerExercise = sets
                do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
            }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity, minHeight: 52).padding().background(.regularMaterial)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 100 || ids.isEmpty)
        }
        .alert("Couldn’t save template", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
    }
}
