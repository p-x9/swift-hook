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

    /// First function hook failed.
    /// It is possible that the symbol exists but is not called from anywhere.
    /// Or you may be re-hooking the same function.
    case failedToHookFirstFunction

    /// Second function hook failed.
    /// It is possible that the symbol exists but is not called from anywhere.
    /// Or you may be re-hooking the same function.
    case failedToHookSecondFunction

    case failedToExchangeMethodImplementation

    case failedToHookFunction
    case failedToHookMethod
    case failedToSetOriginal
}
