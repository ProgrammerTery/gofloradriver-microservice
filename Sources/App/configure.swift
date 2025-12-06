import Vapor
import Leaf

// configures your application
public func configure(_ app: Application) async throws {
    
    // Configure server to run on port 8081
    app.http.server.configuration.port = 8081
    
    // Serve files from Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Configure Leaf templating engine
    app.views.use(.leaf)
    
    // Configure session middleware for driver authentication state
    app.sessions.use(.memory)
    app.middleware.use(app.sessions.middleware)
    
    // Register routes
    try routes(app)

    // Register UI controllers for Service Fees and Invoices
    try app.register(collection: ServiceFeesUIController())
    try app.register(collection: InvoicesUIController())
}