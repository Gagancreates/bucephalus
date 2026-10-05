import Foundation
import SwiftData

// How to change what a meeting stores without losing anyone's data:
//
// 1. Never edit the stored properties of a released schema (`SchemaV1.Meeting`, `SchemaV2.Meeting`).
// 2. Copy the latest model into a new `SchemaVN` with the change, point the `Meeting` typealias at it,
//    and update `CurrentSchema`.
// 3. Add the new schema to `MeetingMigrationPlan.schemas` and a stage from the previous one in `stages`
//    (`.lightweight` for added or removed fields, `.custom` when values need converting).
//
// The store is copied aside before every open, and a store that fails to open is never deleted.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Meeting.self] }
}

/// Adds speaker-labelled transcript segments, speaker names and starring.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Meeting.self] }
}

typealias CurrentSchema = SchemaV2

enum MeetingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

enum Storage {
    private static let backupsToKeep = 5

    static func openContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration()
        backUpStore(at: configuration.url)
        return try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: MeetingMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Copies the database aside before it is opened (and possibly migrated). One copy per day, newest few kept.
    private static func backUpStore(at store: URL) {
        let files = FileManager.default
        guard files.fileExists(atPath: store.path) else { return }

        let root = URL.applicationSupportDirectory.appending(path: "StoreBackups")
        let day = Date.now.formatted(.iso8601.year().month().day())
        let folder = root.appending(path: day)
        guard !files.fileExists(atPath: folder.path) else { return }

        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: store.path + suffix)
            if files.fileExists(atPath: source.path) {
                try? files.copyItem(at: source, to: folder.appending(path: source.lastPathComponent))
            }
        }

        let all = ((try? files.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
        for old in all.dropLast(backupsToKeep) {
            try? files.removeItem(at: root.appending(path: old))
        }
    }
}
