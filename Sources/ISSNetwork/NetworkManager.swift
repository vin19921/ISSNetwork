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
        return URLSession.shared
            .dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                // throw an error if response is nil
                guard let response = output.response as? HTTPURLResponse, (200 ..< 300) ~= response.statusCode else {
                    let code = (output.response as? HTTPURLResponse)?.statusCode ?? 0
                    throw APIError.serverError(code: code, error: "Something went wrong, please try again later.")
                }

                // Convert the data to a JSON string for printing
                if let jsonString = String(data: output.data, encoding: .utf8) {
                    print("JSON Response:\n\(jsonString)")
                } else {
                    print("Unable to convert data to JSON string.")
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
