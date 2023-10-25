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
        return fetchURLResponse(urlRequest: req.buildURLRequest(with: url))
            .flatMap { (result: T) -> AnyPublisher<T, APIError> in
                return Just(result)
                    .setFailureType(to: APIError.self)
                    .eraseToAnyPublisher()
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.invalidJSON(String(describing: error.localizedDescription))
                }
            }
//            .catch { error -> AnyPublisher<T, APIError> in
//                if case APIError.unauthorized = error {
//                    // Handle token refresh here
//                    return self.handleTokenRefreshAndRetry(request: req)
//                } else {
//                    return Fail(error: error).eraseToAnyPublisher()
//                }
//            }
    }

    private func handleTokenRefreshAndRetry<T>(request: NetworkRequest) -> AnyPublisher<T, APIError>
        where T: Decodable, T: Encodable
    {
        // Implement your token refresh logic here.
        // This can include making a refresh token request and updating the access token.
        self.fetchRefreshTokenRequest()
            .flatMap { response in
                if let appToken = response.data.token.appToken {
                    UserDefaults.standard.set(response.data.token.appToken, forKey: "accessToken")
                    UserDefaults.standard.set(response.data.token.refreshToken, forKey: "refreshToken")
                    var requestWithNewAccessToken = request
                    requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(appToken, forKey: "x-access-token")
                    return self.fetchURLResponse(urlRequest: requestWithNewAccessToken)
                } else {
                    return Fail<T, APIError>(error: .refreshTokenError("Missing appToken"))
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }


    public func requestRefreshToken<T>(_ req: NetworkRequest) -> AnyPublisher<T, APIError>
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
        return fetchRefreshTokenURLResponse(urlRequest: req.buildURLRequest(with: url))
    }

    public func requestWithNewToken<T>(_ urlRequest: URLRequest) -> AnyPublisher<T, APIError>
        where T: Decodable, T: Encodable
    {
        if !networkMonitor.isNetworkReachable() {
            return AnyPublisher(Fail<T, APIError>(error: APIError.internetError("Please check you network connection and try again")))
        }
//        guard let url = URL(string: baseURL + req.url) else {
//            // Return a fail publisher if the url is invalid
//            return AnyPublisher(Fail<T, APIError>(error: APIError.badURL("Invalid Url")))
//        }
        // We use the dataTaskPublisher from the URLSession which gives us a publisher to play around with.
        return fetchURLResponse(urlRequest: urlRequest)
    }

    func fetchRefreshTokenURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
                     // Use flatMap to handle token refresh asynchronously
                    print("Token Failed ::: \(response.statusCode)")
                    throw APIError.refreshTokenError("Refresh Token Error")
                 }

                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
                    throw APIError.serverError(code: code, error: "Something went wrong, please try again later.")
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
                // return error if json decoding fails
                return APIError.invalidJSON(String(describing: error.localizedDescription))
            }
            .eraseToAnyPublisher()
    }

//    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
//        print("Request ::: \(urlRequest)")
//
//        return URLSession.shared
//            .dataTaskPublisher(for: urlRequest)
//            .tryMap { output in
//                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
//                    return self.fetchRefreshTokenRequest()
//                        .sink(receiveCompletion: { completion in
//                            switch completion {
//                            case .finished:
//                                break // No error to handle in this case.
//                            case .failure(let error):
//                                // Handle the error here
//                                print("Refresh Token Failure: \(error)")
//                            }
//                        }, receiveValue: { response in
//                            // Handle the successful response here
//                            print("Refresh Token Success: \(response)")
//                            if let appToken = response.data.token.appToken {
//                                UserDefaults.standard.set(response.data.token.appToken, forKey: "accessToken")
//                                UserDefaults.standard.set(response.data.token.refreshToken, forKey: "refreshToken")
//                                return fetchWithNewToken(urlRequest: urlRequest)
//                            } else {
//                                // Handle the absence of the appToken
//                                throw APIError.refreshTokenError("Refresh Token Error")
//                            }
//                        })
//                        .store(in: &self.cancellables)
//                } else {
//                    // Continue with the subsequent steps when the response status code is not 401.
//                    return output.data
//                }
//            }
//            .mapError { error in
//                if let apiError = error as? APIError {
//                    return apiError
//                }
//                return APIError.refreshTokenError("Unknown error occurred")
//            }
//            .eraseToAnyPublisher()
//    }

    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")

        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {

                    return AuthManager.shared.refreshToken()
                        .flatMap { refreshTokenResponse in
                            // Update the request with the new token and retry the request
                            var requestWithNewAccessToken = urlRequest
                            requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(refreshTokenResponse.data.token.appToken, forKey: "x-access-token")

                            return URLSession.shared.dataTaskPublisher(for: requestWithNewAccessToken)
                        }
                        .tryMap { newOutput in
                            // Continue with the subsequent steps when the response status code is not 401.
                            return newOutput.data
                        }
                        .eraseToAnyPublisher()

                } else {
                    // Continue with the subsequent steps when the response status code is not 401.
                    return output.data
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.invalidJSON(String(describing: error.localizedDescription))
            }
            .eraseToAnyPublisher()
    }

//    func handleTokenRefreshAndRequest<T>(_ urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
//        return self.fetchRefreshTokenRequest()
//            .tryMap { refreshTokenResponse in
//                if let appToken = refreshTokenResponse.data.token.appToken {
//                    // Update the headers with the new appToken
//                    var requestWithNewAccessToken = urlRequest
//                    requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(appToken, forKey: "x-access-token")
//                    return requestWithNewAccessToken
//
//                } else {
//                    // Handle the absence of the appToken
//                    throw APIError.refreshTokenError("Missing appToken")
//                }
//            }
//            .flatMap { updatedRequest in
//                return URLSession.shared
//                    .dataTaskPublisher(for: updatedRequest)
//                    .tryMap { output in
//                        return output.data
//                    }
//                    .decode(type: T.self, decoder: JSONDecoder())
//                    .mapError { error in
//                        if let apiError = error as? APIError {
//                            return apiError
//                        }
//                        return APIError.invalidJSON(String(describing: error.localizedDescription))
//                    }
//                    .eraseToAnyPublisher()
//            }
//            .eraseToAnyPublisher()
//    }

//    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
//        print("Request ::: \(urlRequest)")
//        return URLSession.shared
//            .dataTaskPublisher(for: urlRequest)
//            .tryMap { output in
//                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
//                     // Use flatMap to handle token refresh asynchronously
//                    self.fetchRefreshTokenRequest()
//                        .sink(receiveCompletion: { completion in
//                            switch completion {
//                            case .finished:
//                                break // No error to handle in this case.
//                            case .failure(let error):
//                                // Handle the error here
//                                print("Refresh Token Failure: \(error)")
//                            }
//                        }, receiveValue: { response in
//                            // Handle the successful response here
//                            print("Refresh Token Success: \(response)")
//                            if let appToken = response.data.token.appToken {
//                                UserDefaults.standard.set(response.data.token.appToken, forKey: "accessToken")
//                                UserDefaults.standard.set(response.data.token.refreshToken, forKey: "refreshToken")
//)
//                            } else {
//                                // Handle the absence of the appToken
//                                throw APIError.refreshTokenError("Refresh Token Error")
//                            }
//                        })
//                        .store(in: &self.cancellables)
//                 }
//                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
//                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
//                    throw APIError.serverError(code: code, error: "Something went wrong, please try again later.")
//                }
//
//                do {
//                    let jsonData = String(data: output.data, encoding: .utf8)
//                    print("jsonResponse ::: \n\(jsonData)")
//
//                } catch {
//                    print("Error decoding JSON: \(error)")
//                }
//
//                return output.data
//            }
//            .decode(type: T.self, decoder: JSONDecoder())
//            .mapError { error in
//                if let apiError = error as? APIError {
//                    return apiError
//                }
//                // return error if json decoding fails
//                return APIError.invalidJSON(String(describing: error.localizedDescription))
//            }
//            .eraseToAnyPublisher()
//    }

    func fetchRefreshTokenRequest() -> AnyPublisher<RefreshTokenResponse, Error> {
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

    func fetchWithNewToken<T>(urlRequest: URLRequest) -> AnyPublisher<T, Error> where T: Decodable, T: Encodable {
        let accessToken = UserDefaults.standard.string(forKey: "accessToken") ?? ""
        var requestWithNewAccessToken = urlRequest
        requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(accessToken, forKey: "x-access-token")
        let sentRequest: AnyPublisher<T, APIError> = self.requestWithNewToken(requestWithNewAccessToken)

        return sentRequest
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }


//    func fetchRefreshTokenRequest() -> AnyPublisher<RefreshTokenResponse, Error> {
//        // Implement your refresh token request logic here
//        let refreshTokenURL = URL(string: "your_refresh_token_endpoint_here")!
//        let refreshTokenRequest = URLRequest(url: refreshTokenURL)
//
//        return URLSession.shared
//            .dataTaskPublisher(for: refreshTokenRequest)
//            .map(\.data)
//            .decode(type: RefreshTokenResponse.self, decoder: JSONDecoder())
//            .eraseToAnyPublisher()
//    }
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
