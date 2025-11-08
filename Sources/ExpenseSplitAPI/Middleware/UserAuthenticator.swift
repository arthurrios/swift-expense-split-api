//
//  UserAuthenticator.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 08/11/25.
//

import Vapor
import JWT

struct UserAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = UserPayload
    
    func authenticate(jwt: UserPayload, for request: Request) async throws {
        guard let user = try await User.find(jwt.userId, on: request.db) else {
            return
        }
        
        request.auth.login(user)
    }
}
