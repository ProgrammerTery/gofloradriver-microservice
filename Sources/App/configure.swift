import Vapor
import Leaf

// configures your application
public func configure(_ app: Application) async throws {

    // 1. Create a custom JSON Decoder
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // 2. Create a custom JSON Encoder (usually you want both to match)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    // 3. Register them globally with ContentConfiguration
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    ContentConfiguration.global.use(encoder: encoder, for: .json)

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
