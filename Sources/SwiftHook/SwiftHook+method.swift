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

    public static func hookMethod(
        _ target: String,
        _ replacement: String,
        _ original: String? = nil,
        for `class`: AnyClass
    ) throws {
        var isSucceeded: Bool
        isSucceeded = hookImplWithObjCRuntime(
            target,
            replacement,
            original,
            for: `class`
        )
        if isSucceeded { return }

        isSucceeded = hookImplWithVtable(
            target,
            replacement,
            original,
            for: `class`
        )
        if isSucceeded { return }

        throw SwiftHookError.failedToHookMethod
    }
}

extension SwiftHook {
    private static func searchSymbolsFromVtable(
        _ first: String,
        _ second: String,
        _ third: String? = nil,
        for `class`: AnyClass
    ) -> (
        UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        UnsafeMutablePointer<ClassMetadata.SIMP?>?
    ) {
        guard let metadata = reflect(`class`.self) as? ClassMetadata else {
            return (nil, nil, nil)
        }

        let shouldSearchThird = third != nil

        var firstEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?
        var secondEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?
        var thirdEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?

        for entry in metadata.vtable {
            let entryPtr = unsafeBitCast(entry.pointee, to: UnsafeRawPointer.self)
            guard let (_, symbol) = MachOImage.symbol(for: entryPtr) else {
                continue
            }

            // mangled
            var mangled = String(cString: symbol.nameC)
            if mangled == first { firstEntry = entry }
            if mangled == second { secondEntry = entry }
            if let third, mangled == third { thirdEntry = entry }
            if firstEntry != nil && secondEntry != nil,
               !shouldSearchThird || thirdEntry != nil {
                break
            }

            // mangled (omitted first `_`)
            mangled = String(cString: symbol.nameC + 1)
            if mangled == first { firstEntry = entry }
            if mangled == second { secondEntry = entry }
            if let third, mangled == third { thirdEntry = entry }
            if firstEntry != nil && secondEntry != nil,
               !shouldSearchThird || thirdEntry != nil {
                break
            }

            // demangled
            let demangled = stdlib_demangleName(mangled)
            if demangled == first { firstEntry = entry }
            if demangled == second { secondEntry = entry }
            if let third, demangled == third { thirdEntry = entry }
            if firstEntry != nil && secondEntry != nil,
               !shouldSearchThird || thirdEntry != nil {
                break
            }
        }

        return (firstEntry, secondEntry, thirdEntry)
    }
}

extension SwiftHook {
    private static func exchangeImplWithVtable(
        _ first: String,
        _ second: String,
        for `class`: AnyClass
    ) -> Bool {
        let (firstEntry, secondEntry, _) = searchSymbolsFromVtable(
            first,
            second,
            for: `class`
        )

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

extension SwiftHook {
    private static func hookImplWithVtable(
        _ target: String,
        _ replacement: String,
        _ original: String?,
        for `class`: AnyClass
    ) -> Bool {
        let entries = searchSymbolsFromVtable(
            target,
            replacement,
            original,
            for: `class`
        )
        let (targetEntry, replacementEntry, originalEntry) = entries

        if original != nil && originalEntry == nil {
            return false
        }

        if let targetEntry, let replacementEntry  {
            originalEntry?.pointee = targetEntry.pointee
            targetEntry.pointee = replacementEntry.pointee

            return true
        }

        return false
    }

    private static func hookImplWithObjCRuntime(
        _ target: String,
        _ replacement: String,
        _ original: String?,
        for `class`: AnyClass
    ) -> Bool {
        let targetSelector = NSSelectorFromString(target)
        let replacementSelector = NSSelectorFromString(replacement)

        let target = class_getInstanceMethod(`class`, targetSelector) ??
        class_getClassMethod(`class`, targetSelector)
        let replacement = class_getInstanceMethod(`class`, replacementSelector) ??
        class_getClassMethod(`class`, replacementSelector)

        var originalMethod: Method?
        if let original {
            let originalSelector = NSSelectorFromString(original)
            originalMethod = class_getInstanceMethod(`class`, originalSelector) ??
            class_getClassMethod(`class`, originalSelector)
        }

        guard original == nil || originalMethod != nil else {
            return false
        }

        guard let target, let replacement else {
            return false
        }

        if let originalMethod {
            method_setImplementation(originalMethod, method_getImplementation(target))
        }
        method_setImplementation(target, method_getImplementation(replacement))

        return true
    }
}
