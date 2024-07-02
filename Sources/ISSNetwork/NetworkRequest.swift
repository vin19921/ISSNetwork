//
//  NetworkRequest.swift
//  
//
//  Copyright by iSoftStone 2024.
//

import Foundation

public struct NetworkRequest {
    let url: String
    let headers: [String: String]?
    let body: Data?
    let httpMethod: HTTPMethod

    private enum Constants {
        static let applicationJSON = "application/json"
        static let contentType = "Content-Type"
    }

    public init(url: String,
                headers: [String: String]? = nil,
                reqBody: Encodable? = nil,
                httpMethod: HTTPMethod)
    {
        self.url = url
        self.headers = headers
        body = reqBody?.encode()
        self.httpMethod = httpMethod
    }

    func buildURLRequest(with url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)

        urlRequest.httpMethod = httpMethod.rawValue
        urlRequest.httpBody = body

        if let headers = headers {
            for (field, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: field)
            }
        }
        urlRequest.setValue(Constants.applicationJSON, forHTTPHeaderField: Constants.contentType)

        return urlRequest
    }
}

public enum Header: String {
    case Bearer
}


public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public enum APIError: Error, Equatable {
    case badURL(_ error: String)
    case invalidJSON(_ error: String)
    case serverError(code: Int, error: String)
    case internetError(_ error: String)
    case authenticationError(code: Int, error: String)
    case refreshTokenError(_ error: String)
}

public extension Encodable {
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

public struct RequestBody {
    public let keyValues: [(key: String, value: String)]

    public init(keyValues: [(key: String, value: String)]) {
        self.keyValues = keyValues
    }
}

public struct StandardResponse: Codable {
    public let resultCode: Int
    public let resultMessage: String

    // Provide a custom implementation of the Decodable initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultCode = try container.decode(Int.self, forKey: .resultCode)
        resultMessage = try container.decode(String.self, forKey: .resultMessage)
    }

    // Define CodingKeys to map JSON keys to struct properties
    private enum CodingKeys: String, CodingKey {
        case resultCode
        case resultMessage
    }
}

extension URLRequest {
    mutating func updateHeaders(_ newHeaders: [String: String]) {
        for (field, value) in newHeaders {
            self.setValue(value, forHTTPHeaderField: field)
        }
    }
}
