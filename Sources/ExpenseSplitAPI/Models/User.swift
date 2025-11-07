//
//  User.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 06/11/25.
//

import Vapor
import Fluent
import JWT

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Children(for: \.$user)
    var tokens: [UserToken]
    
    @Siblings(through: ActivityParticipant.self, from: \.$user, to: \.$activity)
    var activities: [Activity]
    
    @Siblings(through: ExpenseParticipant.self, from: \.$user, to: \.$expense)
    var expenses: [Expense]
    
    init() {}
    
    init(id: UUID? = nil,
         name: String,
         email: String,
         passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}

// MARK: - ModelAuthenticate
extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email as KeyPath<User, Field<String>>
    static let passwordHashKey = \User.$passwordHash as KeyPath<User, Field<String>>
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - JWT Payload
struct UserPayload: JWTPayload {
    var userId: UUID
    var email: String
    var exp: ExpirationClaim
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
