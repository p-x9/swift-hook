//
//  SwiftHook+function.swift
//
//
//  Created by p-x9 on 2023/12/22.
//
//

import Foundation
import MachO
@_implementationOnly import fishhook
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

        let (_, replacementSymbol) = try searchSymbols(
            &target,
            &replacement,
            isMangled: isMangled
        )

        if let originalName = original,
           let (_, symbol) = MachOImage.symbols(
            named: originalName,
            mangled: isMangled
           ).first(where: {
               $1.nlist.sectionNumber != nil
           }) {
            original = String(cString: symbol.nameC + 1)
        }

        isSucceeded = try _hookFuncImplementation(
            target,
            replacement,
            replacementSymbol,
            original: original
        )

        if isSucceeded { return }

        throw SwiftHookError.failedToHookFunction
    }
}

extension SwiftHook {
    private static func searchSymbols(
        _ first: inout String,
        _ second: inout String,
        isMangled: Bool
    ) throws -> (UnsafeMutableRawPointer, UnsafeMutableRawPointer) {
        var firstSymbol: UnsafeMutableRawPointer?
        var secondSymbol: UnsafeMutableRawPointer?

        if let (machO, symbol) = MachOImage.symbols(
            named: first,
            mangled: isMangled
        ).first(where: {
            $1.nlist.sectionNumber != nil
        }) {
            firstSymbol = .init(
                mutating: machO.ptr.advanced(by: symbol.offset)
            )
            first = String(cString: symbol.nameC + 1)
        }

        if let (machO, symbol) = MachOImage.symbols(
            named: second,
            mangled: isMangled
        ).first(where: {
            $1.nlist.sectionNumber != nil
        }) {
            secondSymbol = .init(
                mutating: machO.ptr.advanced(by: symbol.offset)
            )
            second = String(cString: symbol.nameC + 1)
        }

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

}

extension SwiftHook {
    private static var replaced1: UnsafeMutableRawPointer?
    private static var replaced2: UnsafeMutableRawPointer?

    @discardableResult
    private static func _exchangeFuncImplementation(
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
        Self.replaced1 = nil
        let f2s: Bool = rebindSymbol(
            name: first,
            replacement: secondSymbol,
            replaced: &Self.replaced1
        )

        // hook second function
        Self.replaced2 = nil
        let s2f: Bool = rebindSymbol(
            name: second,
            replacement: firstSymbol,
            replaced: &Self.replaced2
        )

        guard f2s && s2f else {
            return false
        }

        guard Self.replaced1 != nil else {
            throw SwiftHookError.failedToHookFirstFunction
        }
        guard Self.replaced2 != nil else {
            throw SwiftHookError.failedToHookSecondFunction
        }

        return true
    }
}

extension SwiftHook {
    @discardableResult
    private static func _hookFuncImplementation(
        _ target: String,
        _ replacement: String,
        _ replacementSymbol:  UnsafeMutableRawPointer,
        original: String?
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


        Self.replaced1 = nil
        let result: Bool = rebindSymbol(
            name: target,
            replacement: replacementSymbol,
            replaced: &Self.replaced1
        )

        guard result else { return false }

        guard let replaced = Self.replaced1 else {
            return false
        }

        if let original {
            var originalReplaced: UnsafeMutableRawPointer?
            let result: Bool = rebindSymbol(
                name: original,
                replacement: replaced,
                replaced: &originalReplaced
            )
            guard result else { throw SwiftHookError.failedToSetOriginal }

            guard let originalReplaced,
                  Int(bitPattern: originalReplaced) != -1 else {
                throw SwiftHookError.failedToSetOriginal
            }
        }

        return true
    }
}
