//
//  UserToken.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 06/11/25.
//

import Vapor
import Fluent

final class UserToken: Model, Content, @unchecked Sendable {
    static let schema = "user_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?
    
    init() {}
    
    init(id: UUID? = nil,
         value: String,
         userID: UUID,
         expiresAt: Date? = nil) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}

extension UserToken: ModelTokenAuthenticatable {

    typealias User = ExpenseSplitAPI.User
    
    static let valueKey = \UserToken.$value as KeyPath<UserToken, Field<String>>
    static let userKey = \UserToken.$user as KeyPath<UserToken, Parent<User>>
    
    var isValid: Bool {
        guard let expiresAt = expiresAt else { return true }
        return expiresAt > Date()
    }
}
