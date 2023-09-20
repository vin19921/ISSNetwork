//
//  NetworkRequest.swift
//  
//
//  Copyright by iSoftStone 2023.
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
}

public extension Encodable {
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

public struct RequestBody: Encodable {
    public let key: String
    public let value: String
}
