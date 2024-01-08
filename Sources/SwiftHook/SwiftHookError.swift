//
//  SwiftHookError.swift
//
//
//  Created by p-x9 on 2024/01/08.
//  
//

import Foundation

public enum SwiftHookError: Error {
    case failedToExchangeFuncImplementation
    case firstSymbolIsNotFound
    case secondSymbolIsNotFound
    case firstAndSecondSymbolAreNotFound

    case failedToExchangeMethodImplementation
}
