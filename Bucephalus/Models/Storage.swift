import Foundation
import SwiftData

// How to change what a meeting stores without losing anyone's data:
//
// 1. Never edit the stored properties of a released schema (`SchemaV1.Meeting`).
// 2. Copy the model into a new `SchemaV2` with the change, and point the `Meeting` typealias at it.
// 3. Add `SchemaV2` to `MeetingMigrationPlan.schemas` and a stage from V1 to V2 in `stages`
//    (`.lightweight` for added or removed fields, `.custom` when values need converting).
//
// The store is copied aside before every open, and a store that fails to open is never deleted.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Meeting.self] }
}

enum MeetingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Storage {
    private static let backupsToKeep = 5

    static func openContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration()
        backUpStore(at: configuration.url)
        return try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
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
