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
}

@objcMembers
class ObjCClassItem: NSObject {
    dynamic func mul2(_ val: Int) -> Int { 2 * val }
    dynamic func add2(_ val: Int) -> Int { 2 + val }
}
