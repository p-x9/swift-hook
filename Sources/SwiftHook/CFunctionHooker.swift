//
//  CFunctionHooker.swift
//
//
//  Created by p-x9 on 2024/02/17.
//  
//

import Foundation
@_implementationOnly import fishhook

enum CFunctionHooker {
    static var hookedFunctions: [HookFunctionInfo] = []

    private static let lock = NSRecursiveLock()

    static func fishhook(_ info: HookFunctionInfo) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let result = rebindSymbol(
            name: info.target,
            replacement: info.replacementAddress,
            replaced: &info.replacedAddress
        )

        if result { hookedFunctions.append(info) }

        return result
    }
}
