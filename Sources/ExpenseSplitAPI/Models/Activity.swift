//
//  Activity.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 06/11/25.
//

import Vapor
import Fluent

final class Activity: Model, Content, @unchecked Sendable {
    static let schema = "activities"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "activity_date")
    var activityDate: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Siblings(through: ActivityParticipant.self, from: \.$activity, to: \.$user)
    var participants: [User]
    
    @Children(for: \.$activity)
    var expenses: [Expense]
    
    init() {}
    
    init(id: UUID? = nil,
         name: String,
         activityDate: Date) {
        self.id = id
        self.name = name
        self.activityDate = activityDate
    }
}

// MARK: - Pivot Table for Activity-User Relationship
final class ActivityParticipant: Model, @unchecked Sendable {
    static let schema = "activity_participants"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "activity_id")
    var activity: Activity
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "joined_at", on: .create)
    var joinedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil,
         activityID: UUID,
         userID: UUID
    ) {
        self.id = id
        self.$activity.id = activityID
        self.$user.id = userID
    }
}
