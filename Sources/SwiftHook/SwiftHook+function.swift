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

        for i in 0..<_dyld_image_count() {
            let machO = MachOImage(ptr: _dyld_get_image_header(i))
            if let symbol = machO.symbol(
                named: first,
                mangled: isMangled
            ), symbol.nlist.sectionNumber != nil {
                firstSymbol = .init(
                    mutating: machO.ptr.advanced(by: symbol.offset)
                )
                first = String(cString: symbol.nameC + 1)
            }
            if let symbol = machO.symbol(
                named: second,
                mangled: isMangled
            ), symbol.nlist.sectionNumber != nil {
                secondSymbol = .init(
                    mutating: machO.ptr.advanced(by: symbol.offset)
                )
                second = String(cString: symbol.nameC + 1)
            }

            if firstSymbol != nil && secondSymbol != nil { break }
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

            let f2s: Bool = rebindSymbol(
                name: first,
                replacement: secondSymbol,
                replaced: nil
            )
            let s2f: Bool = rebindSymbol(
                name: second,
                replacement: firstSymbol,
                replaced: nil
            )

            return f2s && s2f
        }
        return false
    }
}
