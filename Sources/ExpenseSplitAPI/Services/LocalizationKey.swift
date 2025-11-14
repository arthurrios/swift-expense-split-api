//
//  LocalizationKey.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

enum LocalizationKey: String {
    
    // MARK: - User Errors
    case signupNameMinLength = "errors.signup.name.minLength"
    case signupEmailInvalid = "errors.signup.email.invalid"
    case signupPasswordMinLength = "errors.signup.password.minLength"
    case signinEmailRequired = "errors.signin.email.required"
    case signinPasswordRequired = "errors.signin.password.required"
    case generalInvalidRequest = "errors.general.invalidRequest"
    case validationDuplicateParticipants = "errors.validation.duplicateParticipants"
    case authEmailAlreadyRegistered = "errors.auth.emailAlreadyRegistered"
    case authInvalidCredentials = "errors.auth.invalidCredentials"
    
    // MARK: - Activity Errors
    case activityTitleMinLength = "errors.activity.title.minLength"
    case activityNotFound = "errors.activity.notFound"
    case activityNotParticipant = "errors.activity.notParticipant"
    case activityForbidden = "errors.activity.forbidden"
    
    // MARK: - Expense Errors
    case expenseTitleMinLength = "errors.expense.title.minLength"
    case expenseAmountInvalid = "errors.expense.amount.invalid"
    case expenseParticipantsEmpty = "errors.expense.participants.empty"
    case expenseParticipantsDuplicate = "errors.expense.participants.duplicate"
    case expenseNotFound = "errors.expense.notFound"
    case expenseNotParticipant = "errors.expense.notParticipant"
    case expensePayerNotFound = "errors.expense.payer.notFound"
    case expensePayerNotParticipant = "errors.expense.payer.notParticipant"
    case expenseParticipantNotFound = "errors.expense.participant.notFound"
    case expenseParticipantNotInActivity = "errors.expense.participant.notInActivity"
    case expensePaymentAmountInvalid = "errors.expense.payment.amount.invalid"
    case expensePaymentExceedsDebt = "errors.expense.payment.exceedsDebt"
    case expenseForbidden = "errors.expense.forbidden"
}
