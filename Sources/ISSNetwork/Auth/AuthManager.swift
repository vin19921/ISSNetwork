//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 25/10/2023.
//


final class AuthManager {
    static let shared = AuthManager()

    var accessToken: String?
    var refreshToken: String?

    func refreshToken() -> AnyPublisher<RefreshTokenResponse, Error> {
        let accessToken = UserDefaults.standard.object(forKey: "accessToken") ?? ""
        let refreshToken = UserDefaults.standard.object(forKey: "refreshToken") ?? ""
        print("accessToken : \(accessToken)")
        print("refreshToken : \(refreshToken)")
        let request = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
                                     headers: ["x-access-token": "\(refreshToken)"],
                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
        let sentRequest: AnyPublisher<RefreshTokenResponse, APIError> = self.requestRefreshToken(request)

        return sentRequest
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}
