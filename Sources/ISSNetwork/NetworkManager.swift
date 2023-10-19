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
//            .flatMap { (data: Data) -> AnyPublisher<T, APIError> in
//                // Check if the response status code is 401 (Unauthorized)
//                if let response = req.response as? HTTPURLResponse, response.statusCode == 401 {
//                    // Token has expired, initiate token refresh here.
//                    return refreshToken()
//                        .flatMap { newAccessToken in
//                            // Retry the original request with the new access token
//                            //                        let updatedRequest = req.withUpdatedHeaders(["x-access-token": newAccessToken])
//                            //                        return self.fetchURLResponse(urlRequest: updatedRequest)
//                            print("newAccessToken ::: \(newAccessToken)")
//                        }
//                        .eraseToAnyPublisher()
//                } else {
//                    // Response is not 401, continue as is
//                    return Just(data)
//                        .decode(type: T.self, decoder: JSONDecoder())
//                        .mapError { error in
//                            if let apiError = error as? APIError {
//                                return apiError
//                            }
//                            return APIError.invalidJSON(String(describing: error.localizedDescription))
//                        }
//                        .eraseToAnyPublisher()
//                }
//            }
    }

    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
                     // Use flatMap to handle token refresh asynchronously
                    print("Token Expired ::: \(response.statusCode)")
                    throw APIError.authenticationError(code: response.statusCode, error: "Token Expired.")
                 }
                // throw an error if response is nil
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
                    switch apiError {
                    case let APIError.authenticationError(code, error):
                        return APIError.authenticationError(code: code, error: String(describing: error.localizedDescription))
                    default:
                        return apiError
                    }
                }
                // return error if json decoding fails
                return APIError.invalidJSON(String(describing: error.localizedDescription))
            }
            .eraseToAnyPublisher()
    }

//    func refreshToken() -> AnyPublisher<RefreshTokenResponse, APIError> {
//        // Implement the token refresh logic here and return the new access token as a RefreshTokenResponse.
//        // You can use a separate network request to refresh the token.
//
////        let refreshTokenURL = URL(string: "Your refresh token endpoint URL")!
////        var refreshTokenRequest = URLRequest(url: refreshTokenURL)
////        refreshTokenRequest.httpMethod = "POST"
//        let request = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
//                                     headers: ["x-access-token": "\(String(describing: accessToken))"],
//                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
//
//        // Customize the refresh token request as needed, e.g., add headers, body, etc.
//
//        return URLSession.shared.dataTaskPublisher(for: request)
//            .tryMap { output in
//                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
//                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
//                    throw APIError.serverError(code: code, error: "Token refresh request failed.")
//                }
//
//                do {
//                    let decoder = JSONDecoder()
//                    let refreshTokenResponse = try decoder.decode(RefreshTokenResponse.self, from: output.data)
//                    return refreshTokenResponse
//                } catch {
//                    throw APIError.invalidJSON(String(describing: error.localizedDescription))
//                }
//            }
//            .mapError { error in
//                if let apiError = error as? APIError {
//                    return apiError
//                }
//                return APIError.networkError("Network request failed: \(error.localizedDescription)")
//            }
//            .eraseToAnyPublisher()
//    }

//    func refreshAccessToken() -> AnyPublisher<String, APIError> {
//        // Simulate an asynchronous token refresh process
//        return Future { promise in
//            // Add your actual token refresh logic here, such as making a network request
//            // and getting the new token.
//
//            // For the sake of the example, we'll simulate a successful refresh.
//            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
//                // Replace this with your actual refreshed token
//                let newToken = "newAccessToken123"
//                promise(.success(newToken))
//            }
//
//            // In case of an error, you can use promise(.failure(error)) to send an error.
//            // Replace the simulation with your actual error handling.
//        }
//        .mapError { error in
//            // If there's an error during the token refresh, map it to APIError
//            return APIError.invalidJSON(String(describing: error.localizedDescription))
//        }
//        .eraseToAnyPublisher()
//    }

//    func makeRefreshToken() -> AnyPublisher<String, Error> {
//        return Future<String, Error> { [weak self] promise in
//            guard let self = self else { return promise(.failure("CommonServiceError.emptyData")) }
//
////            print("isNetworkReachable ::: \(AppCoreService.networkMonitor.isNetworkReachable())")
////            guard AppCoreService.networkMonitor.isNetworkReachable() else {
////                return promise(.failure("CommonServiceError.internetFailure"))
////            }
//
//            self.refreshTokenRequest()
//                .sink(receiveCompletion: { completion in
//                    if case .failure(let error) = completion {
//                        promise(.failure(error))
//                    }
//                }, receiveValue: { response in
//                    promise(.success(response))
//                })
//                .store(in: &self.cancellables)
//        }
//        .eraseToAnyPublisher()
//    }
////
//    private func refreshTokenRequest() -> AnyPublisher<String, Error> {
//        let request = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
////                                     reqBody: request,
//                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
//        let sentRequest: AnyPublisher<LoginResponse, APIError> = networkRequest.request(request)
//
//        return sentRequest
//            .mapError { $0 as Error }
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
