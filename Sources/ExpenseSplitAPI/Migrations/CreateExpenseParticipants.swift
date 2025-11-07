//
//  CreateExpenseParticipants.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent

struct CreateExpenseParticipants: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("expense_participants")
            .id()
            .field("expense_id", .uuid, .required, .references("expenses", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("amount_owed_in_cents", .int, .required)
            .field("added_at", .datetime)
            .unique(on: "expense_id", "user_id")
            .create()
    }
    
    func revert(on database: any Database) async throws {
        
    }
}
