import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct AppSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("restAlertsEnabled") private var alertsEnabled = false
    @AppStorage("restoreGeneration") private var restoreGeneration = 0
    @State private var requestingPermission = false
    @State private var exporting = false
    @State private var importing = false
    @State private var document: ExportDocument?
    @State private var exportType = UTType.json
    @State private var pendingRestore: Data?
    @State private var restoreDescription = ""
    @State private var confirmingRestore = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Rest timer") {
                Toggle("Notify when rest ends", isOn: Binding(get: { alertsEnabled }, set: { enabled in
                    if !enabled { RestAlerts.shared.disable(); return }
                    requestingPermission = true
                    Task {
                        defer { requestingPermission = false }
                        do {
                            guard try await RestAlerts.shared.enable() else {
                                message = "Rest alerts are not permitted. You can allow notifications in iPhone Settings."
                                return
                            }
                            for session in try context.fetch(FetchDescriptor<WorkoutSession>()) where session.status == .active {
                                RestAlerts.shared.schedule(sessionID: session.id, profileName: session.profile?.name ?? "", deadline: session.restEndsAt)
                            }
                        } catch { message = error.localizedDescription }
                    }
                })).disabled(requestingPermission)
                Text("A sound and notification announce the end of your 3-minute rest, even while locked. Focus and notification settings may silence alerts.")
                    .font(.caption).foregroundStyle(.secondary)
                #if os(iOS)
                Button("Open iPhone notification settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                #endif
            }
            Section("Backup and export — both profiles") {
                Button { export(csv: false) } label: { Label("Save full backup", systemImage: "externaldrive").frame(minHeight: 48) }
                Button { export(csv: true) } label: { Label("Export sets as CSV", systemImage: "tablecells").frame(minHeight: 48) }
                Text("Full backups include photos, templates, history, gym visits, and rewards. Save the JSON file somewhere safe, such as iCloud Drive. CSV is for viewing your sets and cannot restore the app.")
                    .font(.caption).foregroundStyle(.secondary)
                Button { importing = true } label: { Label("Restore full backup", systemImage: "arrow.down.doc").frame(minHeight: 48) }
                Text("Restoring replaces both profiles’ local data. Save a current backup first if you want to keep it. Rest alerts are turned off after restore.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .fileExporter(isPresented: $exporting, document: document, contentType: exportType,
            defaultFilename: exportType == .json ? "FitnessTracker-backup" : "FitnessTracker-sets") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let archive = try BackupService.decode(data)
                pendingRestore = data
                restoreDescription = "Replace local data with \(archive.profiles.count) profiles, \(archive.sessions.count) workouts and \(archive.sets.count) sets from the backup dated \(archive.exportedAt.formatted(date: .abbreviated, time: .shortened))?"
                confirmingRestore = true
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Restore backup?", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Replace local data", role: .destructive) {
                guard let data = pendingRestore else { return }
                do {
                    try BackupService.restore(data, context: context)
                    restoreGeneration += 1
                    pendingRestore = nil
                    dismiss()
                } catch { message = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: { Text(restoreDescription) }
        .alert("Fitness Tracker", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: { Text(message ?? "") }
    }

    private func export(csv: Bool) {
        do {
            document = ExportDocument(data: try csv ? BackupService.csv(context: context) : BackupService.export(context: context))
            exportType = csv ? .commaSeparatedText : .json
            exporting = true
        } catch { message = error.localizedDescription }
    }
}
