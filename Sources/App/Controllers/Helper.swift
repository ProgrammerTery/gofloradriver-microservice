//
//  Helper.swift
//  DriverMicroservice
//
//  Created by Terence Changadeya on 6/12/2025.
//
import Vapor

  public func makeAPIRequest(req: Request, method: HTTPMethod, endpoint: String,  body: ByteBuffer? = nil, driverToken: String? = nil) async throws -> ClientResponse {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        if let token = driverToken {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        let clientRequest = ClientRequest(
            method: method,
            url: URI(string: endpoint),
            headers: headers,
            body: body
        )

        return try await req.client.send(clientRequest)
    }
