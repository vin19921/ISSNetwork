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
    }

    func fetchURLResponse<T>(urlRequest: URLRequest) -> AnyPublisher<T, APIError> where T: Decodable, T: Encodable {
        print("Request ::: \(urlRequest)")
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, response.statusCode == 401 {
                     // Use flatMap to handle token refresh asynchronously
//                     return refreshAccessToken()
//                         .tryMap { newAccessToken in
//                             // After refreshing the token, retry the request with the updated token
//                             var updatedRequest = req.buildURLRequest(with: url)
//                             // Update the Authorization header with the new access token
//                             updatedRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
//
//                             // Retry the request with the updated token
//                             return fetchURLResponse(urlRequest: updatedRequest)
//                         }
//                         .eraseToAnyPublisher()
                    print("Token Expired ::: \(response.statusCode)")
                 }
                // throw an error if response is nil
                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
                    let allHeaderFields = (output.response as? HTTPURLResponse)?.allHeaderFields ?? ""
                    print("Error ::: \(code), AllHeaderFields ::: \(allHeaderFields)")
                    throw APIError.serverError(code: code, error: "Something went wrong, please try again later.")
                }

                do {
                    let jsonData = String(data: output.data, encoding: .utf8)
                    print("jsonResponse ::: \n\(jsonData)")
//                    let response = try JSONDecoder().decode(StandardResponse.self, from: output.data)
//
//                    if response.resultCode == 1 {
//                        throw APIError.serverError(code: response.resultCode, error: response.resultMessage)
//                    } else {
//                        print("ResultCode is not 1.")
//                    }
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
