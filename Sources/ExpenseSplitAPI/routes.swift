import Vapor

func routes(_ app: Application) throws {
    // Health
    app.get("health") { _ async -> HTTPStatus in .ok }
    app.get { _ async -> String in "Expense Split API - Version 1.0" }
    
    let api = app.grouped("api", "v1")
    
    // Public auth routes
    let authController = AuthController()
    let authRoutes = api.grouped("users")
    authRoutes.post("sign-up", use: authController.signUp)
    authRoutes.post("sign-in", use: authController.signIn)
    
    // Protected routes (JWT)
    let protected = api.grouped(UserAuthenticator(), User.guardMiddleware())
    protected.get("users", "me", use: authController.getProfile)
}
