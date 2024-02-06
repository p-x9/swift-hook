//
//  SwiftHook+method.swift
//
//
//  Created by p-x9 on 2023/12/22.
//
//

import Foundation
@_implementationOnly import fishhook
@_implementationOnly import Echo
@_implementationOnly import MachOKit

extension SwiftHook {
    public static func exchangeMethodImplementation(
        _ first: String,
        _ second: String,
        for `class`: AnyClass
    ) throws {
        var isSucceeded: Bool
        isSucceeded = exchangeImplWithObjCRuntime(
            first,
            second,
            for: `class`
        )
        if isSucceeded { return }

        isSucceeded = exchangeImplWithVtable(
            first,
            second,
            for: `class`
        )
        if isSucceeded { return }

        throw SwiftHookError.failedToExchangeMethodImplementation
    }
}

extension SwiftHook {
    private static func exchangeImplWithVtable(
        _ first: String,
        _ second: String,
        for `class`: AnyClass
    ) -> Bool {
        guard let metadata = reflect(`class`.self) as? ClassMetadata else {
            return false
        }

        var firstEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?
        var secondEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?

        for entry in metadata.vtable {
            var info = Dl_info()
            dladdr(unsafeBitCast(entry.pointee, to: UnsafeRawPointer.self), &info)
            guard let dli_sname = info.dli_sname else {
                continue
            }

            // mangled
            let mangled = String(cString: dli_sname)
            if mangled == first { firstEntry = entry }
            if mangled == second { secondEntry = entry }
            if firstEntry != nil && secondEntry != nil {
                break
            }

            // demangled
            let demangled = stdlib_demangleName(mangled)
            if demangled == first { firstEntry = entry }
            if demangled == second { secondEntry = entry }
            if firstEntry != nil && secondEntry != nil {
                break
            }
        }

        if let firstEntry, let secondEntry  {
            var tmp: ClassMetadata.SIMP?
            tmp = firstEntry.pointee
            firstEntry.pointee = secondEntry.pointee
            secondEntry.pointee = tmp

            return true
        }

        return false
    }

    private static func exchangeImplWithObjCRuntime(
        _ first: String,
        _ second: String,
        for `class`: AnyClass
    ) -> Bool {
        let firstSelector = NSSelectorFromString(first)
        let secondSelector = NSSelectorFromString(second)

        let first = class_getInstanceMethod(`class`, firstSelector) ??
            class_getClassMethod(`class`, firstSelector)
        let second = class_getInstanceMethod(`class`, secondSelector) ??
            class_getClassMethod(`class`, secondSelector)

        guard let first, let second else {
            return false
        }

        method_exchangeImplementations(first, second)

        return true
    }
}
