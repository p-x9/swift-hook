//
//  functions.swift
//
//
//  Created by p-x9 on 2023/11/27.
//  
//

import Foundation

@_silgen_name ("setjmp")
func setjump(_: UnsafeMutablePointer<jmp_buf>) -> Int32

@_silgen_name ("longjmp")
func longjump(_: UnsafeMutablePointer<jmp_buf>, _: Int32) -> Never

func new_empty_buf() -> jmp_buf {
    var buf = Data(count: MemoryLayout<jmp_buf>.size)
    return withUnsafeBytes(of: &buf) { buf in
        guard let baseAddress = buf.baseAddress else {
            fatalError()
        }
        return baseAddress
            .assumingMemoryBound(to: jmp_buf.self)
            .pointee
    }
}

var buf: jmp_buf = new_empty_buf()

@_disfavoredOverload
public func hook_assertionFailure(
    _ prefix: StaticString,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line,
    flags: UInt32
) -> Never {
    print("😃", "hook", message, file, line)
    return longjump(&buf, 1)
}

public func hook_assertionFailure(
    _ prefix: StaticString,
    _ message: StaticString,
    file: StaticString = #file,
    line: UInt = #line,
    flags: UInt32
) -> Never {
    print("😃", "hook", message, file, line)
    return longjump(&buf, 1)
}

@_disfavoredOverload
public func XXXXhook_assertionFailure(
    _ prefix: StaticString,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line,
    flags: UInt32
) -> Never {
    print( "😃", "XXXhook", message, file, line)
    return longjump(&buf, 1)
}

public func XXXXhook_assertionFailure(
    _ prefix: StaticString,
    _ message: StaticString,
    file: StaticString = #file,
    line: UInt = #line,
    flags: UInt32
) -> Never {
    print( "😃", "XXXhook", message, file, line)
    return longjump(&buf, 1)
}


public func targetFunction() -> String {
    "target function"
}

public func replacementFunction() -> String {
    "replacement function"
}

public func originalFunction() -> String {
    ""
}
