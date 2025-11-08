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
}
