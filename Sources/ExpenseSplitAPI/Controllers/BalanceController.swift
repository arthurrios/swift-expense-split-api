//
//  BalanceController.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 19/11/25.
//

import Vapor
import Fluent

struct BalanceController {
    let balanceService = BalanceService()
    let compensationService = CompensationService()
    
    // MARK: - Activity Balance
    func getActivityBalance(req: Request) async throws -> ActivityBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Verify activity exists
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Verify user is participant
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
        
        return try await balanceService.calculateActivityBalance(
            activityId: activityId,
            on: req.db
        )
    }
    
    // MARK: - Balance Between Two Users
    func getBalanceBetweenUsers(req: Request) async throws -> BalanceBetweenUsersResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId1 = req.parameters.get("userId1", as: UUID.self),
              let userId2 = req.parameters.get("userId2", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Verify authenticated user is one of the two users
        guard user.id == userId1 || user.id == userId2 else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityForbidden,
                arguments: [:],
                locale: req.locale
            )
        }
        
        return try await compensationService.calculateBalanceBetweenUsers(
            userId1: userId1,
            userId2: userId2,
            on: req.db
        )
    }
    
    // MARK: - User Global Balance
    func getUserGlobalBalance(req: Request) async throws -> UserGlobalBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Verify authenticated user is requesting their own balance
        guard user.id == userId else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityForbidden,
                arguments: [:],
                locale: req.locale
            )
        }
        
        return try await compensationService.calculateUserGlobalBalance(
            userId: userId,
            on: req.db
        )
    }
    
    // MARK: - Detailed Balance
    func getDetailedBalance(req: Request) async throws -> DetailedBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Verify authenticated user is requesting their own balance
        guard user.id == userId else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityForbidden,
                arguments: [:],
                locale: req.locale
            )
        }
        
        return try await balanceService.calculateDetailedBalance(
            userId: userId,
            on: req.db
        )
    }
}
