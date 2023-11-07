//
//  NetworkManager.swift
//  
//
//  Copyright by iSoftStone 2023.
//

import Combine
import Foundation

@available(iOS 13.0, *)
public protocol Requestable {
    @available(iOS, deprecated: 16.2, message: "Please use the `send(_ request:)` method")
    func request<T: Codable>(_ req: NetworkRequest) -> AnyPublisher<T, APIError>

    func send<Model>(_ request: NetworkRequest) async throws -> Model where Model: Codable
    init(monitor: NetworkConnectivity, session: URLSession)
}

public class NetworkManager: Requestable {
    private let networkMonitor: NetworkConnectivity
    private let session: URLSession
    private let baseURL: String = NetworkConfiguration.environment.baseURL
    private var cancellables = Set<AnyCancellable>()

    public required init(monitor: NetworkConnectivity = ISSNetworkGateway.createNetworkMonitor(), session: URLSession = URLSession.shared) {
        networkMonitor = monitor
        self.session = session
    }

    public func request<T>(_ req: NetworkRequest) -> AnyPublisher<T, APIError>
        where T: Decodable, T: Encodable
    {
        if !networkMonitor.isNetworkReachable() {
            return AnyPublisher(Fail<T, APIError>(error: APIError.internetError("Please check you network connection and try again")))
        }
        guard let url = URL(string: baseURL + req.url) else {
            // Return a fail publisher if the url is invalid
            return AnyPublisher(Fail<T, APIError>(error: APIError.badURL("Invalid Url")))
        }
        // We use the dataTaskPublisher from the URLSession which gives us a publisher to play around with.
        return fetchURLResponse(urlRequest: req.buildURLRequest(with: url), refreshToken: refreshToken)
    }

    func fetchURLResponse<T>(
        urlRequest: URLRequest,
        refreshToken: @escaping () -> AnyPublisher<RefreshTokenResponse, APIError>
    ) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw APIError.invalidJSON("Invalid response")
                }

                if response.statusCode == 401 {
                    throw APIError.authenticationError(code: 401, error: "Unauthorized request")
                }

                do {
                    let jsonData = String(data: output.data, encoding: .utf8)
                    print("jsonResponse ::: \n\(jsonData)")

                } catch {
                    print("Error decoding JSON: \(error)")
                }

                return output.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.invalidJSON(String(describing: error.localizedDescription))
            }
            .catch { (error: APIError) -> AnyPublisher<T, APIError> in
                if case APIError.authenticationError = error {
                    return refreshToken()
                        .flatMap { response -> AnyPublisher<T, APIError> in
                            // Update the urlRequest with the new token
                            let newAppToken = response.data.token.appToken ?? ""
                            let newRefreshToken = response.data.token.refreshToken ?? ""
                            UserDefaults.standard.set(newAppToken, forKey: "accessToken")
                            UserDefaults.standard.set(newRefreshToken, forKey: "refreshToken")
//                            print("appToken ::: \(newAppToken)")
//                            print("refreshToken ::: \(newRefreshToken)")
                            var updatedRequest = urlRequest
                            updatedRequest.setValue(newAppToken, forHTTPHeaderField: "x-access-token")
                            
                            // Retry the network request with the updated request
                            return self.fetchURLResponse(urlRequest: updatedRequest, refreshToken: refreshToken)
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    func refreshToken() -> AnyPublisher<RefreshTokenResponse, APIError> {
        guard let refreshToken = UserDefaults.standard.object(forKey: "refreshToken") as? String else {
            return Fail<RefreshTokenResponse, APIError>(error: APIError.refreshTokenError("Refresh Token Not Found"))
                .eraseToAnyPublisher()
        }

        guard let refreshTokenURL = URL(string: baseURL + NetworkConfiguration.APIEndpoint.refreshToken.path) else {
            return Fail<RefreshTokenResponse, APIError>(error: APIError.refreshTokenError("Invalid refresh token URL"))
                .eraseToAnyPublisher()
        }

        let req = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
                                     headers: ["x-access-token": "\(refreshToken)"],
                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
        print("Request ::: \(req)")

        return URLSession.shared.dataTaskPublisher(for: req.buildURLRequest(with: refreshTokenURL))
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw APIError.invalidJSON("Invalid response")
                }

                if response.statusCode == 401 {
                    throw APIError.refreshTokenError("refreshTokenError")
                }

                do {
                    let jsonData = String(data: output.data, encoding: .utf8)
                    print(jsonData)
                } catch {
                    print("Error decoding JSON: \(error)")
                }
                return output.data
            }
            .decode(type: RefreshTokenResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    switch apiError {
                    case .refreshTokenError:
                        NotificationCenter.default.post(name: Notification.Name("refreshTokenErrorNotification"), object: nil)
                    default:
                        break
                    }
                    return apiError
                }
                return APIError.refreshTokenError("Token refresh failed")
            }
            .eraseToAnyPublisher()
    }
}

public extension NetworkManager {
    func send<Model>(_ request: NetworkRequest) async throws -> Model where Model: Codable {
        guard let url = URL(string: request.url)
        else {
            throw APIError.badURL("Invalid URL (`\(request.url)`) provided.")
        }

        // Error for this need to be considered here
        let urlRequest = request.buildURLRequest(with: url)
        let (data, _) = try await session.data(for: urlRequest)
        let model = try JSONDecoder().decode(Model.self, from: data)
        return model
    }
}
