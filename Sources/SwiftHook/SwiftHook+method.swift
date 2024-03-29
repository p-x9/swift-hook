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

        /* Use Objective-C Runtime */
        isSucceeded = exchangeImplWithObjCRuntime(
            first,
            second,
            for: `class`
        )
        if isSucceeded { return }

        let (firstEntry, secondEntry, _) = searchSymbolsFromVtable(
            first,
            second,
            for: `class`
        )

        /* Swap VTable entry */
        isSucceeded = exchangeImplWithVtable(
            first,
            second,
            firstEntry,
            secondEntry
        )
        if isSucceeded { return }

        var first: String = first
        var second: String = second
        let (firstSymbol, secondSymbol) = try searchSymbols(
            &first,
            &second,
            isMangled: false
        )

        /* Other */
        switch (firstEntry, secondEntry, firstSymbol, secondSymbol) {
        case let (firstEntry?, nil, _, secondSymbol?):
            try exchangeImplWithVtableAndSymbol(
                first,
                second,
                firstEntry,
                secondSymbol
            )
            return
        case let (nil, secondEntry?, firstSymbol?, _):
            try exchangeImplWithVtableAndSymbol(
                second,
                first,
                secondEntry,
                firstSymbol
            )
            return
        case let (nil, nil, firstSymbol?, secondSymbol?):
            try _exchangeFuncImplementation(first, second, firstSymbol, secondSymbol)
            return
        default: break
        }

        throw SwiftHookError.failedToExchangeMethodImplementation
    }

    public static func hookMethod(
        _ target: String,
        _ replacement: String,
        _ original: String? = nil,
        for `class`: AnyClass
    ) throws {
        var isSucceeded: Bool

        /* Use Objective-C Runtime */
        isSucceeded = hookImplWithObjCRuntime(
            target,
            replacement,
            original,
            for: `class`
        )
        if isSucceeded { return }

        let entries = searchSymbolsFromVtable(
            target,
            replacement,
            original,
            for: `class`
        )
        let (targetEntry, replacementEntry, originalEntry) = entries

        var original: String? = original
        var originalSymbol: UnsafeMutableRawPointer?
        if originalEntry == nil,
           let originalName = original {
            var originalName = originalName
            originalSymbol = searchSymbol(&originalName, isMangled: false)
            original = originalName
        }

        /* Swap VTable entry */
        isSucceeded = hookImplWithVtable(
            target,
            replacement,
            original,
            targetEntry,
            replacementEntry,
            originalEntry,
            originalSymbol
        )
        if isSucceeded { return }

        var target: String = target
        var replacement: String = replacement
        let (targetSymbol, replacementSymbol) = try searchSymbols(
            &target,
            &replacement,
            isMangled: false
        )

        /* Other */
        var replacedSymbol: UnsafeMutableRawPointer?
        switch (targetEntry, replacementEntry, targetSymbol, replacementSymbol) {
        case let (targetEntry?, nil, _, replacementSymbol?):
            replacedSymbol = try hookImplWithVtableWithSymbol(
                target,
                replacement,
                targetEntry,
                replacementSymbol
            )
        case let (nil, replacementEntry?, targetSymbol?, _):
            replacedSymbol = try hookImplWithVtableWithSymbol(
                target,
                replacement,
                targetSymbol,
                replacementEntry
            )
        case let (nil, nil, targetSymbol?, replacementSymbol?):
            replacedSymbol = try hookImplWithVtableWithSymbol(
                target,
                replacement,
                targetSymbol,
                replacementSymbol
            )
        default: break
        }

        if let replacedSymbol {
            if let originalEntry {
                originalEntry.pointee = unsafeBitCast(replacedSymbol, to: ClassMetadata.SIMP.self)
            } else if let original, let originalSymbol {
               try  _hookFuncImplementation(
                    target: original,
                    replacement: target,
                    original: nil,
                    targetSymbol: originalSymbol,
                    replacementSymbol: replacedSymbol,
                    originalSymbol: nil
                )
            } else if original != nil {
                throw SwiftHookError.failedToSetOriginal
            }
            return
        }

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

    private static func searchSymbols(
        _ first: inout String,
        _ second: inout String,
        isMangled: Bool
    ) throws -> (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) {
        let firstSymbol: UnsafeMutableRawPointer? = searchSymbol(
            &first,
            isMangled: isMangled
        )
        let secondSymbol: UnsafeMutableRawPointer? = searchSymbol(
            &second,
            isMangled: isMangled
        )

        return (firstSymbol, secondSymbol)
    }
}

extension SwiftHook {
    private static func exchangeImplWithVtable(
        _ first: String,
        _ second: String,
        _ firstEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        _ secondEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?
    ) -> Bool {
        if let firstEntry, let secondEntry  {
            var tmp: ClassMetadata.SIMP?
            tmp = firstEntry.pointee
            firstEntry.pointee = secondEntry.pointee
            secondEntry.pointee = tmp

            return true
        }

        return false
    }

    private static func exchangeImplWithVtableAndSymbol(
        _ first: String,
        _ second: String,
        _ firstEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>,
        _ secondSymbol: UnsafeMutableRawPointer
    ) throws {
        let tmp = firstEntry.pointee
        firstEntry.pointee = unsafeBitCast(secondSymbol, to: ClassMetadata.SIMP.self)
        try _hookFuncImplementation(
            target: second,
            replacement: first,
            original: nil,
            targetSymbol: secondSymbol,
            replacementSymbol: unsafeBitCast(tmp, to: UnsafeMutableRawPointer.self),
            originalSymbol: nil
        )
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
        _ targetEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        _ replacementEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        _ originalEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>?,
        _ originalSymbol: UnsafeMutableRawPointer?
    ) -> Bool {
        if original != nil && originalEntry == nil && originalSymbol == nil {
            return false
        }

        if let targetEntry, let replacementEntry  {
            if let originalEntry {
                originalEntry.pointee = targetEntry.pointee
            } else if let original, let originalSymbol {
                do {
                    try _hookFuncImplementation(
                        target: original,
                        replacement: target,
                        original: nil,
                        targetSymbol: originalSymbol,
                        replacementSymbol: unsafeBitCast(targetEntry.pointee, to: UnsafeMutableRawPointer.self),
                        originalSymbol: nil
                    )
                } catch { return false }
            }
            targetEntry.pointee = replacementEntry.pointee

            return true
        }

        return false
    }

    private static func hookImplWithVtableWithSymbol(
        _ target: String,
        _ replacement: String,
        _ targetEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>,
        _ replacementSymbol: UnsafeMutableRawPointer
    ) throws -> UnsafeMutableRawPointer {
        let targetOriginal = targetEntry.pointee
        targetEntry.pointee = unsafeBitCast(replacementSymbol, to: ClassMetadata.SIMP.self)
        return unsafeBitCast(targetOriginal, to: UnsafeMutableRawPointer.self)
    }

    private static func hookImplWithVtableWithSymbol(
        _ target: String,
        _ replacement: String,
        _ targetSymbol: UnsafeMutableRawPointer,
        _ replacementEntry: UnsafeMutablePointer<ClassMetadata.SIMP?>
    ) throws -> UnsafeMutableRawPointer {
        try _hookFuncImplementation(
            target: target,
            replacement: replacement,
            original: nil,
            targetSymbol: targetSymbol,
            replacementSymbol: unsafeBitCast(replacementEntry.pointee, to: UnsafeMutableRawPointer.self),
            originalSymbol: nil
        )
        return targetSymbol
    }

    private static func hookImplWithVtableWithSymbol(
        _ target: String,
        _ replacement: String,
        _ targetSymbol: UnsafeMutableRawPointer,
        _ replacementSymbol: UnsafeMutableRawPointer
    ) throws -> UnsafeMutableRawPointer {
        try _hookFuncImplementation(
            target: target,
            replacement: replacement,
            original: nil,
            targetSymbol: targetSymbol,
            replacementSymbol: replacementSymbol,
            originalSymbol: nil
        )
        return targetSymbol
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
