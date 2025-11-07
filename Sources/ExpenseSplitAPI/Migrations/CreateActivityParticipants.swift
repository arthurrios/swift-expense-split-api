//
//  CreateActivityParticipants.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent

struct CreateActivityParticipants: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("activity_participants")
            .id()
            .field("activity_id", .uuid, .required, .references("activities", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("joined_at", .datetime)
            .unique(on: "activity_id", "user_id")
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("activity_participants").delete()
    }
}
