//
//  ExpenseDTOs.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 13/11/25.
//

import Vapor

// MARK: - Create Expense
struct CreateExpenseRequest: Content {
    let title: String
    let amountInCents: Int
    let payerId: UUID?
    let participantsIds: [UUID]
    
    func validate(on req: Request) throws {
        if title.count < 3 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseTitleMinLength,
                arguments: ["min": "3"],
                locale: req.locale
            )
        }
        
        if amountInCents <= 0 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseAmountInvalid,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if participantsIds.isEmpty {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseParticipantsEmpty,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if Set(participantsIds).count != participantsIds.count {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseParticipantsDuplicate,
                arguments: [:],
                locale: req.locale
            )
        }
    }
}

struct CreateExpenseResponse: Content {
    let id: UUID
    let name: String
    let amountInCents: Int
    let payerId: UUID?
    let payerName: String?
    let activityId: UUID
    let participants: [ParticipantDebt]
    let createdAt: Date?
    
    struct ParticipantDebt: Content {
        let userId: UUID
        let userName: String
        let amountOwedInCents: Int
    }
}

// MARK: - Update Expense
struct UpdateExpenseRequest: Content {
    let title: String?
    let amountInCents: Int?
    let payerId: UUID?
    let participantsIds: [UUID]?
    
    func validate(on req: Request) throws {
        if let title = title, title.count < 3 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseTitleMinLength,
                arguments: ["min": "3"],
                locale: req.locale
            )
        }
        
        if let amountInCents = amountInCents, amountInCents <= 0 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expenseAmountInvalid,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if let participantsIds = participantsIds {
            if participantsIds.isEmpty {
                throw LocalizedAbortError(
                    status: .badRequest,
                    key: .expenseParticipantsEmpty,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            if Set(participantsIds).count != participantsIds.count {
                throw LocalizedAbortError(
                    status: .badRequest,
                    key: .expenseParticipantsDuplicate,
                    arguments: [:],
                    locale: req.locale
                )
            }
        }
    }
}

// MARK: - Set Payer
struct SetExpensePayerRequest: Content {
    let payerId: UUID
    
    func validate(on req: Request) throws {
        // No validation needed, just presence check
    }
}

struct SetExpensePayerResponse: Content {
    let id: UUID
    let name: String
    let payerId: UUID?
    let payerName: String?
    let updatedAt: Date?
}

// MARK: - List Expenses
struct ExpenseListItem: Content {
    let id: UUID
    let name: String
    let amountInCents: Int
    let payer: PayerInfo?
    let participantsCount: Int
    let createdAt: Date?
    
    struct PayerInfo: Content {
        let userId: UUID
        let name: String
    }
}

struct ExpenseListResponse: Content {
    let expenses: [ExpenseListItem]
}

// MARK: - Expense Detail
struct ExpenseDetailResponse: Content {
    let id: UUID
    let name: String
    let amountInCents: Int
    let payer: PayerInfo?
    let activityId: UUID
    let activityName: String
    let participants: [ParticipantInfo]
    let payments: [PaymentInfo]
    let createdAt: Date?
    
    struct PayerInfo: Content {
        let userId: UUID
        let name: String
        let email: String
    }
    
    struct ParticipantInfo: Content {
        let userId: UUID
        let name: String
        let email: String
        let amountOwedInCents: Int
        let amountPaidInCents: Int
        let remainingDebtInCents: Int
    }
    
    struct PaymentInfo: Content {
        let id: UUID
        let debtorId: UUID
        let debtorName: String
        let amountPaidInCents: Int
        let paidAt: Date?
    }
}

// MARK: - Mark Payment
struct MarkPaymentRequest: Content {
    let amountInCents: Int
    
    func validate(on req: Request) throws {
        if amountInCents <= 0 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .expensePaymentAmountInvalid,
                arguments: [:],
                locale: req.locale
            )
        }
    }
}

struct MarkPaymentResponse: Content {
    let id: UUID
    let expenseId: UUID
    let debtorId: UUID
    let debtorName: String
    let amountPaidInCents: Int
    let paidAt: Date?
}
