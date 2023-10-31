//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 21/09/2023.
//

import Foundation

public struct NetworkConfiguration {
    public static var environment: Environment = .development

    public enum Environment {
        case development
        case production

        public var baseURL: String {
            switch self {
            case .development:
                return "http://175.136.236.153:9108"
            case .production:
                return "http://175.136.236.153:9108"
            }
        }
    }

    public enum APIEndpoint {
        case register
        case getOTP
        case validateRegistrationOTP
        case validateResetPasswordOTP
        case login
        case viewProfile
        case updateProfile
        case refreshToken
        case getUser(userID: Int)

        public var path: String {
            switch self {
            case .register:
                return "/user/register"
            case .getOTP:
                return "/user/otp"
            case .validateRegistrationOTP:
                return "/user/validateOtp"
            case .validateResetPasswordOTP:
                return "/user/resetPWValidateOtp"
            case .login:
                return "/auth/login"
            case .viewProfile:
                return "/user/profile"
            case .updateProfile:
                return "/user/profile"
            case .refreshToken:
                return "/auth/refreshToken"
            case .getUser(let userID):
                return "/user/\(userID)"
            }
        }

        public var httpMethod: HTTPMethod {
            switch self {
            case .register:
                return .POST
            case .getOTP:
                return .POST
            case .validateRegistrationOTP:
                return .POST
            case .validateResetPasswordOTP:
                return .POST
            case .login:
                return .POST
            case .viewProfile:
                return .POST
            case .updateProfile:
                return .PUT
            case .refreshToken:
                return .POST
            case .getUser:
                return .GET
            }
        }
    }
}
