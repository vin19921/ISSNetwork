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

    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
                     // Use flatMap to handle token refresh asynchronously
                    print("Token Expired ::: \(response.statusCode)")
                    self.fetchRefreshTokenRequest()
                        .mapError { error in
                            // Transform the error to APIError.refreshTokenError here.
                            throw APIError.refreshTokenError("APIError.refreshTokenError")
                        }
                        .sink(receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("Refresh Token Failure")
                            }
                        }, receiveValue: { response in
                            print("Refresh Token Success\(response.data.appToken)")
                        })
                        .store(in: &self.cancellables)

//                    throw APIError.authenticationError(code: response.statusCode, error: "authenticationError")
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
                    case let .authenticationError(code, description):
//                        self.fetchRefreshTokenRequest()
//                            .mapError { error in
//                                // Transform the error to APIError.refreshTokenError here.
//                                return APIError.refreshTokenError("APIError.refreshTokenError")
//                            }
//                            .sink(receiveCompletion: { completion in
//                                if case .failure(let error) = completion {
//                                    print("Refresh Token Failure")
//                                }
//                            }, receiveValue: { response in
//                                print("Refresh Token Success\(response.data.appToken)")
//                            })
//                            .store(in: &self.cancellables)
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
        let refreshToken = UserDefaults.standard.object(forKey: "refreshToken")
        let request = NetworkRequest(url: NetworkConfiguration.APIEndpoint.refreshToken.path,
                                     headers: ["x-access-token": "\(String(describing: refreshToken))"],
                                     httpMethod: NetworkConfiguration.APIEndpoint.refreshToken.httpMethod)
        let sentRequest: AnyPublisher<RefreshTokenResponse, APIError> = self.request(request)

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
