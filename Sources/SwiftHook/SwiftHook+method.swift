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
            let mangled = String(cString: dli_sname)
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

@discardableResult
func swizzle(class: AnyClass, orig origSelector: Selector, hooked hookedSelector: Selector) -> Bool {
    guard let origMethod = class_getInstanceMethod(`class`, origSelector),
          let hookedMethod = class_getInstanceMethod(`class`, hookedSelector) else {
        return false
    }

    let didAddMethod = class_addMethod(`class`, origSelector,
                                       method_getImplementation(hookedMethod),
                                       method_getTypeEncoding(hookedMethod))
    if didAddMethod {
        class_replaceMethod(`class`, hookedSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod))
        return true
    }
    method_exchangeImplementations(origMethod, hookedMethod)
    return true
    }
