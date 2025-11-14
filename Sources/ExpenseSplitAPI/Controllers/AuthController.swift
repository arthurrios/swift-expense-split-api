//
//  AuthController.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 08/11/25.
//

import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Sign Up
    func signUp(req: Request) async throws -> SignUpResponse {
        let payload = try req.content.decode(SignUpRequest.self)
        try payload.validate(on: req)
        
        let normalizedEmail = payload.email.lowercased()
        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first()
        
        if existingUser != nil {
            throw LocalizedAbortError(
                status: .conflict,
                key: .authEmailAlreadyRegistered,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let passwordHash = try Bcrypt.hash(payload.password)
        let user = User(
            name: payload.name,
            email: normalizedEmail,
            passwordHash: passwordHash
        )
        
        try await user.save(on: req.db)
        
        let token = try generateToken(for: user, on: req)
        
        return SignUpResponse(
            id: user.id!,
            name: user.name,
            email: user.email,
            token: token
        )
    }
    
    // MARK: - Sign In
    func signIn(req: Request) async throws -> SignInResponse {
        let payload = try req.content.decode(SignInRequest.self)
        try payload.validate(on: req)
        
        let normalizedEmail = payload.email.lowercased()
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first() else {
            throw LocalizedAbortError(
                status: .unauthorized,
                key: .authInvalidCredentials,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard try Bcrypt.verify(payload.password, created: user.passwordHash) else {
            throw LocalizedAbortError(
                status: .unauthorized,
                key: .authInvalidCredentials,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let token = try generateToken(for: user, on: req)
        
        return SignInResponse(
            id: user.id!,
            name: user.name,
            email: user.email,
            token: token
        )
    }
    
    // MARK: - Profile
    func getProfile(req: Request) async throws -> UserProfileResponse {
        let user = try req.auth.require(User.self)
        return UserProfileResponse(from: user)
    }
    
    // MARK: - List Users
    func listUsers(req: Request) async throws -> UserListResponse {
        let user = try req.auth.require(User.self)
        
        // Get all users
        let allUsers = try await User.query(on: req.db).all()
        
        // Check if activityId query parameter is provided
        let activityId = req.query[UUID.self, at: "activityId"]
        
        var participantUserIds: Set<UUID> = []
        
        if let activityId = activityId {
            // Verify activity exists
            guard try await Activity.find(activityId, on: req.db) != nil else {
                throw LocalizedAbortError(
                    status: .notFound,
                    key: .activityNotFound,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            // Verify authenticated user is a participant of the activity
            let isParticipant = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == user.id!)
                .first() != nil
            
            guard isParticipant else {
                throw LocalizedAbortError(
                    status: .forbidden,
                    key: .activityNotParticipant,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            // Get all participants of the activity
            let participants = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .all()
            
            participantUserIds = Set(participants.map { $0.$user.id })
        }
        
        // Map users to response items
        var userItems: [UserListItem] = allUsers.map { user in
            let isInActivity: Bool? = activityId != nil ? participantUserIds.contains(user.id!) : nil
            
            return UserListItem(
                id: user.id!,
                name: user.name,
                email: user.email,
                isInActivity: isInActivity
            )
        }
        
        // Sort: if activityId is provided, participants first
        if activityId != nil {
            userItems.sort { (first, second) -> Bool in
                let firstIsParticipant = first.isInActivity == true
                let secondIsParticipant = second.isInActivity == true
                
                if firstIsParticipant && !secondIsParticipant {
                    return true
                } else if !firstIsParticipant && secondIsParticipant {
                    return false
                } else {
                    // If both are participants or both are not, sort alphabetically by name
                    return first.name < second.name
                }
            }
        }
        
        return UserListResponse(users: userItems)
    }
    
    
    // MARK: - Helpers
    private func generateToken(for user: User, on req: Request) throws -> String {
        let payload = UserPayload(
            userId: user.id!,
            email: user.email,
            exp: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 30))  // 30 days
        )
        
        return try req.jwt.sign(payload)
    }
}
