//
//  File.swift
//  
//
//  Created by Wing Seng Chew on 21/09/2023.
//

import Foundation

struct NetworkConfiguration {
    static var environment: Environment = .development

    enum Environment {
        case development
        case production

        var baseURL: String {
            switch self {
            case .development:
                return "http://175.136.236.153:9108/"
            case .production:
                return "http://175.136.236.153:9108/"
            }
        }
    }
}
