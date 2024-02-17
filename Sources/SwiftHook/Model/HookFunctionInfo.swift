//
//  HookFunctionInfo.swift
//
//
//  Created by p-x9 on 2024/02/17.
//  
//

import Foundation

class HookFunctionInfo {
    let target: String
    let targetAddress: UnsafeMutableRawPointer

    let replacement: String
    let replacementAddress: UnsafeMutableRawPointer

    var replacedAddress: UnsafeMutableRawPointer?

    init(
        target: String,
        targetAddress: UnsafeMutableRawPointer,
        replacement: String,
        replacementAddress: UnsafeMutableRawPointer,
        replacedAddress: UnsafeMutableRawPointer? = nil
    ) {
        self.target = target
        self.targetAddress = targetAddress
        self.replacement = replacement
        self.replacementAddress = replacementAddress
        self.replacedAddress = replacedAddress
    }
}
