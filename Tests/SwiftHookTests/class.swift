//
//  class.swift
//  
//
//  Created by p-x9 on 2024/01/06.
//  
//

import Foundation

class SwiftClassItem {
    init() {}

    func mul2(_ val: Int) -> Int { 2 * val }
    func add2(_ val: Int) -> Int { 2 + val }

    func target() -> String {
        "target"
    }

    func replacement() -> String {
        "replacement"
    }

    func original() -> String {
        "original"
    }

}

@objcMembers
class ObjCClassItem: NSObject {
    dynamic func mul2(_ val: Int) -> Int { 2 * val }
    dynamic func add2(_ val: Int) -> Int { 2 + val }

    dynamic func target() -> String {
        "target"
    }

    dynamic func replacement() -> String {
        "replacement"
    }

    dynamic func original() -> String {
        "original"
    }

}
