import Vapor

func routes(_ app: Application) throws {
    // Simple health check
    app.get("health") { _ async -> HTTPStatus in
        .ok
    }
    
    app.post("api", "v1", "users", "sign-up") { req async throws -> HTTPStatus in
        let payload = try req.content.decode(SignUpRequest.self)
        try payload.validate(on: req)
        return .created
    }
}
