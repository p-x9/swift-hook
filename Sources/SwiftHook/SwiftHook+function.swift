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

        isSucceeded = try _exchangeFuncImplementation(
            first,
            second,
            isMangled: isMangled
        )

        if isSucceeded { return }

        throw SwiftHookError.failedToExchangeFuncImplementation
    }
}

extension SwiftHook {
    private static func _exchangeFuncImplementation(
        _ first: String,
        _ second: String,
        isMangled: Bool
    ) throws -> Bool {
        var first: String = first
        var second: String = second

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

        if firstSymbol == nil {
            throw SwiftHookError.firstSymbolIsNotFound
        }
        if secondSymbol == nil {
            throw SwiftHookError.secondSymbolIsNotFound
        }

        return exchangeFuncImplementation(
            first,
            second,
            firstSymbol,
            secondSymbol
        )
    }

    @discardableResult
    private static func exchangeFuncImplementation(
        _ first: String,
        _ second: String,
        _ firstSymbol:  UnsafeMutableRawPointer?,
        _ secondSymbol:  UnsafeMutableRawPointer?
    ) -> Bool {
        if let firstSymbol, let secondSymbol {
#if DEBUG
            print(stdlib_demangleName(first))
            print("=>")
            print(stdlib_demangleName(second))
            print(firstSymbol, secondSymbol)
#endif

            var replaced1 = UnsafeMutableRawPointer(bitPattern: -1)
            var replaced2 = UnsafeMutableRawPointer(bitPattern: -1)

            let f2s: Bool = rebindSymbol(
                name: first,
                replacement: secondSymbol,
                replaced: &replaced1
            )
            let s2f: Bool = rebindSymbol(
                name: second,
                replacement: firstSymbol,
                replaced: &replaced2
            )

            guard f2s && s2f else {
                return false
            }

            guard let replaced1, let replaced2,
                  Int(bitPattern: replaced1) != -1,
                  Int(bitPattern: replaced2) != -1 else {
#if DEBUG
                print("target function is not used.")
#endif
                return true
            }

            return true
        }
        return false
    }
}
