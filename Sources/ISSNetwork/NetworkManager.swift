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

//    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
//        print("Request ::: \(urlRequest)")
//
//        return URLSession.shared
//            .dataTaskPublisher(for: urlRequest)
//            .tryMap { output in
//                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
//                    // Use flatMap to conditionally handle token refresh asynchronously
//                    print("Token Expired ::: \(response.statusCode)")
//                }
//                // Continue with the subsequent steps when the response status code is not 401.
//                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
//                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
//                    throw APIError.serverError(code: code, error: "Something went wrong, please try again later.")
//                }
//
//                return output.data
//            }
//            .eraseToAnyPublisher()
//    }

    func fetchRefreshTokenURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        
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
                     // Use flatMap to handle token refresh asynchronously
                    self.fetchRefreshTokenRequest()
                        .sink(receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break // No error to handle in this case.
                            case .failure(let error):
                                // Handle the error here
                                print("Refresh Token Failure: \(error)")
                            }
                        }, receiveValue: { response in
                            // Handle the successful response here
                            print("Refresh Token Success: \(response)")
                        })
                        .store(in: &self.cancellables)
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

//    func refreshToken() -> AnyPublisher<RefreshTokenResponse, APIError> {
//        // Assuming you have a refresh token and authentication server endpoint.
//        let refreshToken = UserDefaults.standard.object(forKey: "refreshToken")
//        let refreshTokenEndpoint = NetworkConfiguration.APIEndpoint.refreshToken.path
//
//        // Create a request to refresh the token.
//        guard let url = URL(string: refreshTokenEndpoint) else {
//            return Fail(error: APIError.badURL("Invalid Refresh Token URL"))
//                .eraseToAnyPublisher()
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = NetworkConfiguration.APIEndpoint.refreshToken.httpMethod
//        // You might need to set headers or parameters required by your authentication server.
//
//        return URLSession.shared.dataTaskPublisher(for: request)
//            .map(\.data)
//            .decode(type: RefreshTokenResponse.self, decoder: JSONDecoder())
//            .mapError { error in
//                if let apiError = error as? APIError {
//                    return apiError
//                } else {
//                    return APIError.badURL("Token Refresh Failed: \(error.localizedDescription)")
//                }
//            }
//            .eraseToAnyPublisher()
//    }

    func fetchRefreshTokenRequest() -> AnyPublisher<RefreshTokenResponse, Error> {
        let accessToken = UserDefaults.standard.object(forKey: "accessToken")
        let refreshToken = UserDefaults.standard.object(forKey: "refreshToken")
        print("accessToken : \(accessToken)")
        print("refreshToken : \(refreshToken)")
        let request = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
                                     headers: ["x-access-token": "\(String(describing: refreshToken))"],
                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
        let sentRequest: AnyPublisher<RefreshTokenResponse, APIError> = self.requestRefreshToken(request)

        return sentRequest
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

//    func requestRefreshToken(_ request: NetworkRequest) -> AnyPublisher<RefreshTokenResponse, APIError> {
//        return URLSession.shared.dataTaskPublisher(for: request.buildURLRequest(with: request))
//            .mapError { error in
//                // Map URLSession errors to APIError
//                return APIError.refreshTokenError("Refresh Token Error")
//            }
//            .flatMap { data, response in
//                if let httpResponse = response as? HTTPURLResponse, (200 ..< 300) ~= httpResponse.statusCode {
//                    // If the response status code is in the success range, decode the response
//                    do {
//                        let decodedResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
//                        return Just(decodedResponse)
//                            .setFailureType(to: APIError.self)
//                            .eraseToAnyPublisher()
//                    } catch {
//                        return Fail(error: APIError.invalidJSON(String(describing: error.localizedDescription)))
//                            .eraseToAnyPublisher()
//                    }
//                } else {
//                    // If the response status code is not in the success range, create an APIError
//                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
//                    return Fail(error: APIError.serverError(code: code, error: "Server error"))
//                        .eraseToAnyPublisher()
//                }
//            }
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
