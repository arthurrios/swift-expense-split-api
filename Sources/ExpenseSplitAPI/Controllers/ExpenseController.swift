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
        
        guard let _ = try await Activity.find(activityId, on: req.db) else {
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
            guard let _ = try await User.find(payerId, on: req.db) else {
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
            guard let _ = try await User.find(participantId, on: req.db) else {
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
    
    // MARK: - Update Expense
    func update(req: Request) async throws -> CreateExpenseResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let updateRequest = try req.content.decode(UpdateExpenseRequest.self)
        try updateRequest.validate(on: req)
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expenseNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let activityId = expense.$activity.id
        
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
        
        // Update title if provided
        if let newTitle = updateRequest.title {
            expense.name = newTitle
        }
        
        // Update amount if provided
        var shouldRecalculateParticipants = false
        if let newAmount = updateRequest.amountInCents {
            expense.amountInCents = newAmount
            shouldRecalculateParticipants = true
        }
        
        // Update payer if provided
        if let newPayerId = updateRequest.payerId {
            guard let _ = try await User.find(newPayerId, on: req.db) else {
                throw LocalizedAbortError(
                    status: .notFound,
                    key: .expensePayerNotFound,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            let payerIsParticipant = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == newPayerId)
                .first() != nil
            
            guard payerIsParticipant else {
                throw LocalizedAbortError(
                    status: .forbidden,
                    key: .expensePayerNotParticipant,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            expense.$payer.id = newPayerId
        }
        
        // Update participants if provided
        if let newParticipantsIds = updateRequest.participantsIds {
            // Validate all participants exist and are in activity
            for participantId in newParticipantsIds {
                guard let _ = try await User.find(participantId, on: req.db) else {
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
            
            // Delete existing participants
            try await ExpenseParticipant.query(on: req.db)
                .filter(\.$expense.$id == expenseId)
                .delete()
            
            // Calculate new amount per participant
            let amountPerParticipant = expense.amountInCents / newParticipantsIds.count
            
            // Create new participants
            for participantId in newParticipantsIds {
                let expenseParticipant = ExpenseParticipant(
                    expenseID: expenseId,
                    userID: participantId,
                    amountOwedInCents: amountPerParticipant
                )
                try await expenseParticipant.save(on: req.db)
            }
            
            shouldRecalculateParticipants = false // Already recalculated
        } else if shouldRecalculateParticipants {
            // Recalculate amounts for existing participants
            let existingParticipants = try await ExpenseParticipant.query(on: req.db)
                .filter(\.$expense.$id == expenseId)
                .all()
            
            guard !existingParticipants.isEmpty else {
                throw LocalizedAbortError(
                    status: .badRequest,
                    key: .expenseParticipantsEmpty,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            let amountPerParticipant = expense.amountInCents / existingParticipants.count
            
            for participant in existingParticipants {
                participant.amountOwedInCents = amountPerParticipant
                try await participant.save(on: req.db)
            }
        }
        
        try await expense.save(on: req.db)
        
        // Load updated participants for response
        let expenseParticipants = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .with(\.$user)
            .all()
        
        var participantDebts: [CreateExpenseResponse.ParticipantDebt] = []
        for ep in expenseParticipants {
            participantDebts.append(
                CreateExpenseResponse.ParticipantDebt(
                    userId: ep.$user.id,
                    userName: ep.user.name,
                    amountOwedInCents: ep.amountOwedInCents
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
        
        guard let _ = try await Activity.find(activityId, on: req.db) else {
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
    
    // MARK: - Expense Detail
    func detail(req: Request) async throws -> ExpenseDetailResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expenseNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == expense.$activity.id)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .expenseNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        try await expense.$activity.load(on: req.db)
        try await expense.$payer.load(on: req.db)
        try await expense.$participants.load(on: req.db)
        try await expense.$payments.load(on: req.db)
        
        for payment in expense.payments {
            try await payment.$debtor.load(on: req.db)
        }
        
        let expenseParticipants = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .with(\.$user)
            .all()
        
        var paymentsByParticipant: [UUID: Int] = [:]
        for payment in expense.payments {
            let debtorId = payment.$debtor.id
            paymentsByParticipant[debtorId, default: 0] += payment.amountPaidInCents
        }
        
        let participantsInfos: [ExpenseDetailResponse.ParticipantInfo] = expenseParticipants.map { ep in
            let amountPaid = paymentsByParticipant[ep.$user.id, default: 0]
            let remainingDebt = max(0, ep.amountOwedInCents - amountPaid)
            
            return ExpenseDetailResponse.ParticipantInfo(
                userId: ep.$user.id,
                name: ep.user.name,
                email: ep.user.email,
                amountOwedInCents: ep.amountOwedInCents,
                amountPaidInCents: amountPaid,
                remainingDebtInCents: remainingDebt
            )
        }
        
        var payerInfo: ExpenseDetailResponse.PayerInfo? = nil
        if let payer = expense.payer {
            payerInfo = ExpenseDetailResponse.PayerInfo(
                userId: payer.id!,
                name: payer.name,
                email: payer.email
            )
        }
        
        let paymentInfos: [ExpenseDetailResponse.PaymentInfo] = expense.payments.map { payment in
            ExpenseDetailResponse.PaymentInfo(
                id: payment.id!,
                debtorId: payment.$debtor.id,
                debtorName: payment.debtor.name,
                amountPaidInCents: payment.amountPaidInCents,
                paidAt: payment.paidAt
            )
        }
        
        return ExpenseDetailResponse(
            id: expense.id!,
            name: expense.name,
            amountInCents: expense.amountInCents,
            payer: payerInfo,
            activityId: expense.$activity.id,
            activityName: expense.activity.name,
            participants: participantsInfos,
            payments: paymentInfos,
            createdAt: expense.createdAt
        )
    }
    
    // MARK: - Set Payer
    func setPayer(req: Request) async throws -> SetExpensePayerResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let setPayerRequest = try req.content.decode(SetExpensePayerRequest.self)
        try setPayerRequest.validate(on: req)
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expenseNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == expense.$activity.id)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .expenseNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let payer = try await User.find(setPayerRequest.payerId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expensePayerNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let payerIsParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == expense.$activity.id)
            .filter(\.$user.$id == payer.id!)
            .first() != nil
        
        guard payerIsParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .expensePayerNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        expense.$payer.id = setPayerRequest.payerId
        try await expense.save(on: req.db)
        
        return SetExpensePayerResponse(
            id: expense.id!,
            name: expense.name,
            payerId: expense.$payer.id,
            payerName: payer.name,
            updatedAt: expense.updatedAt
        )
    }
    
    // MARK: - MArk Payment
    func markPayment(req: Request) async throws -> MarkPaymentResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let markPaymentRequest = try req.content.decode(MarkPaymentRequest.self)
        try markPaymentRequest.validate(on: req)
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expenseNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == expense.$activity.id)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .expenseNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let expenseParticipant = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseParticipantNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let existingPayments = try await ExpensePayment.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .filter(\.$debtor.$id == user.id!)
            .all()
        
        let totalPaid = existingPayments.reduce(0) { $0 + $1.amountPaidInCents }
        let remainingDebt = expenseParticipant.amountOwedInCents - totalPaid
        
        guard markPaymentRequest.amountInCents <= remainingDebt else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expensePaymentExceedsDebt,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let payment = ExpensePayment(
            expenseID: expenseId,
            debtorID: user.id!,
            amountPaidInCents: markPaymentRequest.amountInCents
        )
        
        try await payment.save(on: req.db)
        
        return MarkPaymentResponse(
            id: payment.id!,
            expenseId: expenseId,
            debtorId: user.id!,
            debtorName: user.name,
            amountPaidInCents: markPaymentRequest.amountInCents,
            paidAt: payment.paidAt
        )
    }
    
    // MARK: - Delete Expense
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .expenseNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == expense.$activity.id)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .expenseNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        try await expense.delete(on: req.db)
        
        return .noContent
    }
}
