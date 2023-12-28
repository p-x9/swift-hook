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
        for `class`: AnyClass.Type
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
    }
}

extension SwiftHook {
    private static func exchangeImplWithVtable(
        _ first: String,
        _ second: String,
        for `class`: AnyClass.Type
    ) -> Bool {
        guard let metadata = reflect(`class`.self) as? ClassMetadata else {
            return false
        }

        var firstEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?
        var secondEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?

        for entry in metadata.vtable {
            var info = Dl_info()
            dladdr(unsafeBitCast(entry.pointee, to: UnsafeRawPointer.self), &info)
            let mangled = String(cString: info.dli_sname)
            let demangled = stdlib_demangleName(mangled)

            if mangled == first || demangled == first {
                firstEntry = entry
            }

            if mangled == second || demangled == second {
                secondEntry = entry
            }

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
        for `class`: AnyClass.Type
    ) -> Bool {
        let firstDemangled = stdlib_demangleName(first)
        let secondDemangled = stdlib_demangleName(second)
        let first = class_getInstanceMethod(`class`, NSSelectorFromString(first)) ??
        class_getInstanceMethod(`class`, NSSelectorFromString(firstDemangled))

        let second = class_getInstanceMethod(`class`, NSSelectorFromString(second)) ??
        class_getInstanceMethod(`class`, NSSelectorFromString(secondDemangled))

        guard let first, let second else {
            return false
        }

        method_exchangeImplementations(first, second)

        return true
    }
}
