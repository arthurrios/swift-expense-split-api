//
//  ActivityController.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 12/11/25.
//

import Vapor
import Fluent

struct ActivityController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Create Activity
    func create(req: Request) async throws -> CreateActivityResponse {
        let user = try req.auth.require(User.self)
        let createRequest = try req.content.decode(CreateActivityRequest.self)
        try createRequest.validate(on: req)
        
        let activity = Activity(
            name: createRequest.title,
            activityDate: createRequest.activityDate
        )
        
        try await activity.save(on: req.db)
        
        // Add creator as participant
        let participant = ActivityParticipant(
            activityID: activity.id!,
            userID: user.id!
        )
        
        try await participant.save(on: req.db)
        
        return CreateActivityResponse(
            id: activity.id!,
            name: activity.name,
            activityDate: activity.activityDate,
            createdAt: activity.createdAt
        )
    }
    
    // MARK: - Update Activity
    func update(req: Request) async throws -> CreateActivityResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let updateRequest = try req.content.decode(UpdateActivityRequest.self)
        try updateRequest.validate(on: req)
        
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
        
        // Update fields
        if let newTitle = updateRequest.title {
            activity.name = newTitle
        }
        
        if let newDate = updateRequest.activityDate {
            activity.activityDate = newDate
        }
        
        try await activity.save(on: req.db)
        
        return CreateActivityResponse(
            id: activity.id!,
            name: activity.name,
            activityDate: activity.activityDate,
            createdAt: activity.createdAt
        )
    }
    
    // MARK: - List Activities
    func list(req: Request) async throws -> ActivityListResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Users can only view their own activities
        guard user.id == userId else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityForbidden,
                arguments: [:],
                locale: req.locale
            )
        }
        
        // Get all activities for this user
        let activityParticipants = try await ActivityParticipant.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$activity) { activity in
                activity.with(\.$expenses)
                activity.with(\.$participants)
            }
            .all()
        
        let activities = activityParticipants.map { $0.activity }
        
        let activityItems: [ActivityListItem] = activities.map { activity in
            let totalAmount = activity.expenses.reduce(0) { $0 + $1.amountInCents }
            let participantsCount = activity.participants.count
            let expensesCount = activity.expenses.count
            
            return ActivityListItem(
                id: activity.id!,
                name: activity.name,
                totalAmountInCents: totalAmount,
                activityDate: activity.activityDate,
                participantsAmount: participantsCount,
                expensesAmount: expensesCount
            )
        }
        
        return ActivityListResponse(activities: activityItems)
    }
    
    // MARK: Activity Detail
    func detail(req: Request) async throws -> ActivityDetailResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let activity = try await Activity.query(on: req.db)
            .filter(\.$id == activityId)
            .with(\.$participants)
            .with(\.$expenses)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        try await activity.$expenses.load(on: req.db)
        for expense in activity.expenses {
            try await expense.$payer.load(on: req.db)
            try await expense.$participants.load(on: req.db)
        }
        
        let isParticipant = activity.participants.contains { $0.id == user.id }
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let participants = activity.participants.map { participant in
            ActivityDetailResponse.ParticipantInfo(
                id: participant.id!,
                name: participant.name,
                email: participant.email
            )
        }
        
        let expenses = activity.expenses.map { expense in
            ActivityDetailResponse.ExpenseInfo(
                id: expense.id!,
                name: expense.name,
                amountInCents: expense.amountInCents,
                payerName: expense.payer?.name,
                payerId: expense.$payer.id,
                participantsCount: expense.participants.count
            )
        }
        
        let totalAmount = activity.expenses.reduce(0) { $0 + $1.amountInCents }
        
        return ActivityDetailResponse(
            id: activity.id!,
            name: activity.name,
            activityDate: activity.activityDate,
            participants: participants,
            expenses: expenses,
            totalAmountInCents: totalAmount
        )
    }
    
    // MARK: - Remove Activity
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
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
        
        try await activity.delete(on: req.db)
        
        return .noContent
    }
}
