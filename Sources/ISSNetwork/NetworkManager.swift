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

    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")

        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
                    return self.fetchRefreshTokenRequest()
                        .tryMap { refreshTokenResponse in
                            guard let appToken = refreshTokenResponse.data.token.appToken else {
                                throw APIError.refreshTokenError("Missing appToken")
                            }
                            
                            var requestWithNewAccessToken = urlRequest
                            requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(appToken, forKey: "x-access-token")
                            
                            return requestWithNewAccessToken
                        }
                } else {
                    // Continue with the subsequent steps when the response status code is not 401.
                    return urlRequest
                }
            }
            .flatMap { request in
                return URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { newOutput in
                        return newOutput.data
                    }
                    .decode(type: T.self, decoder: JSONDecoder())
                    .mapError { error in
                        if let apiError = error as? APIError {
                            return apiError
                        }
                        return APIError.invalidJSON(String(describing: error.localizedDescription))
                    }
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
//
////                    self.fetchRefreshTokenRequest()
////                        .sink(receiveCompletion: { completion in
////                            switch completion {
////                            case .finished:
////                                break // No error to handle in this case.
////                            case .failure(let error):
////                                // Handle the error here
////                                print("Refresh Token Failure: \(error)")
////                            }
////                        }, receiveValue: { response in
////                            // Handle the successful response here
////                            print("Refresh Token Success: \(response)")
////                            if let appToken = response.data.token.appToken {
////                                // Update the headers with the new appToken
////                                var requestWithNewAccessToken = urlRequest
////                                requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(appToken, forKey: "x-access-token")
////                                return URLSession.shared
////                                    .dataTaskPublisher(for: requestWithNewAccessToken)
////                                    .tryMap { output in
////                                        return output.data
////                                    }
////                                    .decode(type: T.self, decoder: JSONDecoder())
////                                    .mapError { error in
////                                        if let apiError = error as? APIError {
////                                            return apiError
////                                        }
////                                        return APIError.invalidJSON(String(describing: error.localizedDescription))
////                                    }
////                                    .eraseToAnyPublisher()
////
////                            } else {
////                                // Handle the absence of the appToken
////                                return APIError.refreshTokenError("Missing appToken")
////                            }
////                        })
////                        .store(in: &self.cancellables)
//                    return try self.fetchRefreshTokenRequest()
//                        .tryMap { refreshTokenResponse in
//                            guard let appToken = refreshTokenResponse.data.token.appToken else {
//                                throw APIError.refreshTokenError("Missing appToken")
//                            }
//
//                            var requestWithNewAccessToken = urlRequest
//                            requestWithNewAccessToken.allHTTPHeaderFields?.updateValue(appToken, forKey: "x-access-token")
//
//                            let newRequestPublisher = URLSession.shared.dataTaskPublisher(for: requestWithNewAccessToken)
//                                .tryMap { newOutput in
//                                    return newOutput.data
//                                }
//                                .decode(type: T.self, decoder: JSONDecoder())
//                                .mapError { error in
//                                    if let apiError = error as? APIError {
//                                        return apiError
//                                    }
//                                    return APIError.invalidJSON(String(describing: error.localizedDescription))
//                                }
//
//                            return newRequestPublisher
//                        }
////                        .switchToLatest()
//
//                } else {
//                    // Continue with the subsequent steps when the response status code is not 401.
//                    return output.data
//                }
//            }
//            .decode(type: T.self, decoder: JSONDecoder())
//            .mapError { error in
//                if let apiError = error as? APIError {
//                    return apiError
//                }
//                return APIError.invalidJSON(String(describing: error.localizedDescription))
//            }
//            .eraseToAnyPublisher()
//    }

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

//    public func requestWithNewToken<T>(_ req: NetworkRequest) -> AnyPublisher<T, APIError>
//        where T: Decodable, T: Encodable
//    {
//        if !networkMonitor.isNetworkReachable() {
//            return AnyPublisher(Fail<T, APIError>(error: APIError.internetError("Please check you network connection and try again")))
//        }
//        guard let url = URL(string: baseURL + req.url) else {
//            // Return a fail publisher if the url is invalid
//            return AnyPublisher(Fail<T, APIError>(error: APIError.badURL("Invalid Url")))
//        }
//        // We use the dataTaskPublisher from the URLSession which gives us a publisher to play around with.
//        let accessToken = UserDefaults.standard.object(forKey: "accessToken") ?? ""
//        let refreshToken = UserDefaults.standard.object(forKey: "refreshToken") ?? ""
//        req.headers?.updateValue(accessToken, forKey: "x-access-token")
//
//        return fetchURLResponse(urlRequest: req.buildURLRequest(with: url))
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
