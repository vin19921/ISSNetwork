//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 19/10/2023.
//

public struct TokenDataModel: Codable {
    public let token: RefreshTokenDataModel

    enum CodingKeys: String, CodingKey {
        case token
    }
}

public struct RefreshTokenDataModel: Codable {
    public let appToken: String?
    public let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case appToken
        case refreshToken
    }
}

public struct RefreshTokenResponse: Codable {
    public let resultCode: Int16?
    public let resultMessage: String?
    public let status: Int16?
    public let data: TokenDataModel
}

public extension RefreshTokenResponse {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultCode = try? container.decode(Int16.self, forKey: .resultCode)
        resultMessage = try? container.decode(String.self, forKey: .resultMessage)
        status = try? container.decodeIfPresent(Int16.self, forKey: .status) ?? 0
        data = try container.decode(TokenDataModel.self, forKey: .data)
    }
}
