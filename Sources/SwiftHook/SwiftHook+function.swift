//
//  SwiftHook+function.swift
//
//
//  Created by p-x9 on 2023/12/22.
//
//

import Foundation
import MachO
@_implementationOnly import Echo
@_implementationOnly import MachOKit

extension SwiftHook {
    public static func exchangeFuncImplementation(
        _ first: String,
        _ second: String,
        isMangled: Bool
    ) throws {
        var isSucceeded = false

        var first: String = first
        var second: String = second

        let (firstSymbol, secondSymbol) = try searchSymbols(
            &first,
            &second,
            isMangled: isMangled
        )

        isSucceeded = try _exchangeFuncImplementation(
            first,
            second,
            firstSymbol,
            secondSymbol
        )

        if isSucceeded { return }

        throw SwiftHookError.failedToExchangeFuncImplementation
    }

    public static func hookFunction(
        _ target: String,
        _ replacement: String,
        _ original: String? = nil,
        isMangled: Bool
    ) throws {
        var isSucceeded = false

        var target: String = target
        var replacement: String = replacement
        var original: String? = original
        var originalSymbol: UnsafeMutableRawPointer?

        let (targetSymbol, replacementSymbol) = try searchSymbols(
            &target,
            &replacement,
            isMangled: isMangled
        )

        if let originalName = original {
            var originalName = originalName
            originalSymbol = searchSymbol(&originalName, isMangled: isMangled)
            original = originalName
        }

        isSucceeded = try _hookFuncImplementation(
            target: target,
            replacement: replacement,
            original: original,
            targetSymbol: targetSymbol,
            replacementSymbol: replacementSymbol,
            originalSymbol: originalSymbol
        )

        if isSucceeded { return }

        throw SwiftHookError.failedToHookFunction
    }
}

extension SwiftHook {
    @inline(__always)
    private static func searchSymbols(
        _ first: inout String,
        _ second: inout String,
        isMangled: Bool
    ) throws -> (UnsafeMutableRawPointer, UnsafeMutableRawPointer) {
        let firstSymbol: UnsafeMutableRawPointer? = searchSymbol(
            &first,
            isMangled: isMangled
        )
        let secondSymbol: UnsafeMutableRawPointer? = searchSymbol(
            &second,
            isMangled: isMangled
        )

        if firstSymbol == nil && secondSymbol == nil {
            throw SwiftHookError.firstAndSecondSymbolAreNotFound
        }

        guard let firstSymbol else {
            throw SwiftHookError.firstSymbolIsNotFound
        }
        guard let secondSymbol else {
            throw SwiftHookError.secondSymbolIsNotFound
        }

        return (firstSymbol, secondSymbol)
    }

    @inline(__always)
    package static func searchSymbol(
        _ name: inout String,
        isMangled: Bool
    ) -> UnsafeMutableRawPointer? {
        var symbolAddress: UnsafeMutableRawPointer?

        if let (machO, symbol) = MachOImage.symbols(
            named: name,
            mangled: isMangled
        ).first(where: {
            $1.nlist.sectionNumber != nil
        }) {
            symbolAddress = .init(
                mutating: machO.ptr.advanced(by: symbol.offset)
            )
            name = String(cString: symbol.nameC + 1)
        }

        return symbolAddress
    }
}

extension SwiftHook {
    @discardableResult
    package static func _exchangeFuncImplementation(
        _ first: String,
        _ second: String,
        _ firstSymbol:  UnsafeMutableRawPointer,
        _ secondSymbol:  UnsafeMutableRawPointer
    ) throws -> Bool {
#if DEBUG
        print(stdlib_demangleName(first))
        print("<=>")
        print(stdlib_demangleName(second))
        print(firstSymbol, secondSymbol)
#endif

        // hook first function
        let f2sInfo = HookFunctionInfo(
            target: first,
            targetAddress: firstSymbol,
            replacement: second,
            replacementAddress: secondSymbol
        )
        let f2s = CFunctionHooker.fishhook(f2sInfo)

        // hook second function
        let s2fInfo = HookFunctionInfo(
            target: second,
            targetAddress: secondSymbol,
            replacement: first,
            replacementAddress: firstSymbol
        )
        let s2f = CFunctionHooker.fishhook(s2fInfo)

        guard f2s && s2f else {
            return false
        }

        guard f2sInfo.replacedAddress != nil else {
            throw SwiftHookError.failedToHookFirstFunction
        }
        guard s2fInfo.replacedAddress != nil else {
            throw SwiftHookError.failedToHookSecondFunction
        }

        return true
    }
}

extension SwiftHook {
    @discardableResult
    package static func _hookFuncImplementation(
        target: String,
        replacement: String,
        original: String?,
        targetSymbol: UnsafeMutableRawPointer,
        replacementSymbol: UnsafeMutableRawPointer,
        originalSymbol: UnsafeMutableRawPointer?
    ) throws -> Bool {

#if DEBUG
        if let original {
            print(stdlib_demangleName(original))
            print("=>")
        }
        print(stdlib_demangleName(target))
        print("=>")
        print(stdlib_demangleName(replacement))
#endif

        let targetHookInfo = HookFunctionInfo(
            target: target,
            targetAddress: targetSymbol,
            replacement: replacement,
            replacementAddress: replacementSymbol
        )
        let result: Bool = CFunctionHooker.fishhook(targetHookInfo)

        guard result else { return false }

        guard let replaced = targetHookInfo.replacedAddress else {
            return false
        }

        if let original, let originalSymbol {
            let originalHookInfo = HookFunctionInfo(
                target: original,
                targetAddress: originalSymbol,
                replacement: target,
                replacementAddress: replaced
            )
            let result: Bool = CFunctionHooker.fishhook(originalHookInfo)
            guard result else { throw SwiftHookError.failedToSetOriginal }

            guard originalHookInfo.replacedAddress != nil else {
                throw SwiftHookError.failedToSetOriginal
            }
        }

        return true
    }
}
