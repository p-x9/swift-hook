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
    ) -> Bool {
        if isMangled {
            return exchangeFuncImplementationMangled(first, second)
        } else {
            return exchangeFuncImplementationDeMangled(first, second)
        }
    }
}

extension SwiftHook {
    private static func exchangeFuncImplementationMangled(
        _ first: String,
        _ second: String
    ) -> Bool {
        var firstSymbol: UnsafeMutableRawPointer?
        var secondSymbol: UnsafeMutableRawPointer?

        for i in 0..<_dyld_image_count() {
            let dylib = _dyld_get_image_name(i)
            guard let handle = dlopen(dylib, RTLD_NOW) else {
                continue
            }
            if firstSymbol == nil {
                firstSymbol = dlsym(handle, first.cString(using: .utf8))
            }
            if secondSymbol == nil {
                secondSymbol = dlsym(handle, second.cString(using: .utf8))
            }

            if firstSymbol != nil && secondSymbol != nil { break }
        }

        return exchangeFuncImplementation(
            first,
            second,
            firstSymbol,
            secondSymbol
        )
    }

    private static func exchangeFuncImplementationDeMangled(
        _ first: String,
        _ second: String
    ) -> Bool {
        var first: String = first
        var second: String = second

        var firstSymbol: UnsafeMutableRawPointer?
        var secondSymbol: UnsafeMutableRawPointer?

        for i in 0..<_dyld_image_count() {
            let machO = MachOImage(ptr: _dyld_get_image_header(i))
            if let symbol = machO.symbol(named: first, mangled: false) {
                firstSymbol = .init(
                    mutating: machO.ptr.advanced(by: symbol.offset)
                )
                first = String(cString: symbol.nameC + 1)
            }
            if let symbol = machO.symbol(named: second, mangled: false) {
                secondSymbol = .init(
                    mutating: machO.ptr.advanced(by: symbol.offset)
                )
                second = String(cString: symbol.nameC + 1)
            }


            if firstSymbol != nil && secondSymbol != nil { break }
        }

        return exchangeFuncImplementation(
            first,
            second,
            firstSymbol,
            secondSymbol
        )
    }

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

