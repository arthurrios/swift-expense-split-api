//
//  ExpenseController.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 13/11/25.
//

import Vapor
import Fluent

struct ExpenseController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Create Expense
    func create(req: Request) async throws -> CreateExpenseResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let createRequest = try req.content.decode(CreateExpenseRequest.self)
        try createRequest.validate(on: req)
        
        guard let _activity = try await Activity.find(activityId, on: req.db) else {
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
        
        if let payerId = createRequest.payerId {
            guard let _payer = try await User.find(payerId, on: req.db) else {
                throw LocalizedAbortError(
                    status: .notFound,
                    key: .expensePayerNotFound,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            let payerIsParticipant = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == payerId)
                .first() != nil
            
            guard payerIsParticipant else {
                throw LocalizedAbortError(
                    status: .forbidden,
                    key: .expensePayerNotParticipant,
                    arguments: [:],
                    locale: req.locale
                )
            }
        }
        
        for participantId in createRequest.participantsIds {
            guard let _participant = try await User.find(participantId, on: req.db) else {
                throw LocalizedAbortError(
                    status: .notFound,
                    key: .expenseParticipantNotFound,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            let participantIsInActivity = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == participantId)
                .first() != nil
            
            guard participantIsInActivity else {
                throw LocalizedAbortError(
                    status: .forbidden,
                    key: .expenseParticipantNotInActivity,
                    arguments: [:],
                    locale: req.locale
                )
            }
        }
        
        let expense = Expense(
            name: createRequest.title,
            amountInCents: createRequest.amountInCents,
            payerID: createRequest.payerId,
            activityID: activityId
        )
        
        try await expense.save(on: req.db)
        
        let amountPerParticipant = createRequest.amountInCents / createRequest.participantsIds.count
        
        var participantDebts: [CreateExpenseResponse.ParticipantDebt] = []
        
        for participantId in createRequest.participantsIds {
            let expenseParticipant = ExpenseParticipant(
                expenseID: expense.id!,
                userID: participantId,
                amountOwedInCents: amountPerParticipant
            )
            
            try await expenseParticipant.save(on: req.db)
            
            let participantUser = try await User.find(participantId, on: req.db)!
            participantDebts.append(
                CreateExpenseResponse.ParticipantDebt(
                    userId: participantId,
                    userName: participantUser.name,
                    amountOwedInCents: amountPerParticipant
                )
            )
        }
        
        var payerName: String? = nil
        if let payerId = expense.$payer.id {
            let payer = try await User.find(payerId, on: req.db)!
            payerName = payer.name
        }
        
        return CreateExpenseResponse(
            id: expense.id!,
            name: expense.name,
            amountInCents: expense.amountInCents,
            payerId: expense.$payer.id,
            payerName: payerName,
            activityId: activityId,
            participants: participantDebts,
            createdAt: expense.createdAt
        )
    }
    
    // MARK: - List Expenses
    func list(req: Request) async throws -> ExpenseListResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let _activity = try await Activity.find(activityId, on: req.db) else {
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
        
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .with(\.$payer)
            .with(\.$participants)
            .all()
        
        // Load relationships for all expenses
        for expense in expenses {
            if expense.$payer.id != nil {
                try? await expense.$payer.load(on: req.db)
            }
            try await expense.$participants.load(on: req.db)
        }
        
        let expenseItems: [ExpenseListItem] = expenses.map { expense in
            // Load payer if exists
            var payerInfo: ExpenseListItem.PayerInfo? = nil
            if let payerId = expense.$payer.id, let payer = expense.payer {
                payerInfo = ExpenseListItem.PayerInfo(
                    userId: payerId,
                    name: payer.name
                )
            }
            
            
            // Count participants
            let participantsCount = expense.participants.count
            
            return ExpenseListItem(
                id: expense.id!,
                name: expense.name,
                amountInCents: expense.amountInCents,
                payer: payerInfo,
                participantsCount: participantsCount,
                createdAt: expense.createdAt
            )
        }
        
        return ExpenseListResponse(expenses: expenseItems)
    }
}
