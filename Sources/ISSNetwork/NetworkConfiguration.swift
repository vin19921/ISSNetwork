//
//  NetworkConfiguration.swift
//
//
//  Copyright by iSoftStone 2024.
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
        case changePassword
        case taskList
        case categoryList
        case confirmTask
        case myTaskList
        case remoteConfig
        case timeFrameList
        case createSchedule
        case getScheduleList
        case updateAvailability

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
            case .changePassword:
                return "/auth/changePassword"
            case .taskList:
                return "/task/list"
            case .categoryList:
                return "/category/list"
            case .confirmTask:
                return "/task/occupy"
            case .myTaskList:
                return "/task/occupylist"
            case .remoteConfig:
                return "/remoteConfig"
            case .timeFrameList:
                return "/timeFrame/list"
            case .createSchedule:
                return "/schedule/create"
            case .getScheduleList:
                return "/schedule/list"
            case .updateAvailability:
                return "schedule/update/edit"
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
            case .changePassword:
                return .PUT
            case .taskList:
                return .POST
            case .categoryList:
                return .POST
            case .confirmTask:
                return .POST
            case .myTaskList:
                return .POST
            case .remoteConfig:
                return .POST
            case .timeFrameList:
                return .POST
            case .createSchedule:
                return .POST
            case .getScheduleList:
                return .POST
            case .updateAvailability:
                return .POST
            }
        }
    }
}
