//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 25/10/2023.
//

import Combine
import Foundation

final class AuthManager {
    static let shared = AuthManager()

    var accessToken: String?
    var refreshToken: String?

    func refreshToken() -> AnyPublisher<RefreshTokenResponse, Error> {
        let accessToken = UserDefaults.standard.string(forKey: "accessToken") ?? ""
        let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""
        print("accessToken: \(accessToken)")
        print("refreshToken: \(refreshToken)")

        // Check if tokens are valid, and if not, return an error Publisher
        if accessToken.isEmpty || refreshToken.isEmpty {
            return Fail(error: APIError.authenticationError(code: 401, error: "Tokens not found"))
                .eraseToAnyPublisher()
        }

        // Construct the refresh token request
        let request = NetworkRequest(
            url: NetworkConfiguration.APIEndpoint.refreshToken.path,
            headers: ["x-access-token": refreshToken],
            httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod
        )

        // Call the requestRefreshToken function (define this function to perform the network request)
        return requestRefreshToken(request)
            .eraseToAnyPublisher()
    }

    func requestRefreshToken(_ request: NetworkRequest) -> AnyPublisher<RefreshTokenResponse, Error> {
        // Implement the network request logic here using Combine's URLSession dataTaskPublisher
        // This function should return a Publisher that emits a RefreshTokenResponse or an error.
        // Handle the response and error cases here.
        
        // For example, you might use URLSession like this:
        return URLSession.shared.dataTaskPublisher(for: request.urlRequest())
            .map(\.data)
            .decode(type: RefreshTokenResponse.self, decoder: JSONDecoder())
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}
