import XCTest
import SwiftHook
import MachOKit

// ref: https://github.com/johnno1962/Fortify/blob/main/Sources/Fortify.swift

final class SwiftHookTests: XCTestCase {
    override class func setUp() {
        _ = disableExclusivityChecking

        // If the function is not referenced, the indirect symbol is not generated.
        let function1: (StaticString, StaticString, StaticString, UInt, UInt32) -> Never = XXXXhook_assertionFailure
        let function2: (StaticString, String, StaticString, UInt, UInt32) -> Never = XXXXhook_assertionFailure
        let function3: (StaticString, StaticString, StaticString, UInt, UInt32) -> Never = hook_assertionFailure
        let function4: (StaticString, String, StaticString, UInt, UInt32) -> Never = hook_assertionFailure
        print(function1, function2, function3, function4)
    }

    func testHookFunction() throws {
        XCTAssertEqual(targetFunction(), "target function")
        XCTAssertEqual(replacementFunction(), "replacement function")
        XCTAssertEqual(originalFunction(), "")

        try SwiftHook.hookFunction(
            "$s14SwiftHookTests14targetFunctionSSyF",
            "$s14SwiftHookTests19replacementFunctionSSyF",
            "$s14SwiftHookTests16originalFunctionSSyF",
            isMangled: true
        )

        XCTAssertEqual(targetFunction(), "replacement function")
        XCTAssertEqual(replacementFunction(), "replacement function")
        XCTAssertEqual(originalFunction(), "target function")
    }

    func testExchangeFunc() throws {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ _assertionFailure
        try SwiftHook.exchangeFuncImplementation(
            "$s14SwiftHookTests21hook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2ISus6UInt32VtF",
            "$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtF",
            isMangled: true
        )

        var optional: Int?
        let forceUnwrapped = optional!
    }

    func testExchangeDemangledFunc() throws {
        if setjump(&buf) != 0 {
            return
        }

        // XXXXhook_assertionFailure ⇔ _assertionFailure
        try SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.XXXXhook_assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            "Swift._assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            isMangled: false
        )

        var optional: Int?
        let forceUnwrapped = optional!
    }
}

extension SwiftHookTests {
    func testExchangeFuncInSelfImage() throws {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ XXXXhook_assertionFailure
        try SwiftHook.exchangeFuncImplementation(
            "$s14SwiftHookTests21hook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
            "$s14SwiftHookTests25XXXXhook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
            isMangled: true
        )

        let message = "bbb"
        hook_assertionFailure("aaa", message, flags: 0)
    }

    func testExchangeDemangledFuncInSelfImage() throws {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ XXXXhook_assertionFailure
        try SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.hook_assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            "SwiftHookTests.XXXXhook_assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            isMangled: false
        )

        hook_assertionFailure("aaa", "bbbb", flags: 0)
    }
}

extension SwiftHookTests {
    func testExchangeStructFunction() throws {
        let item = StructItem()

        print(item.printA())
        print(item.printB())
        XCTAssertEqual(item.printA(), "A")
        XCTAssertEqual(item.printB(), "B")

        // printA ⇔ printB
        try SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.StructItem.printA() -> Swift.String",
            "SwiftHookTests.StructItem.printB() -> Swift.String",
            isMangled: false
        )

        print(item.printA())
        print(item.printB())
        XCTAssertEqual(item.printA(), "B")
        XCTAssertEqual(item.printB(), "A")
    }
}

extension SwiftHookTests {
    func testExchangeSwiftClassMethod() throws {
        let item = SwiftClassItem()
        print(item.add2(5))
        XCTAssertEqual(item.add2(5), 7)

        try SwiftHook.exchangeMethodImplementation(
            "SwiftHookTests.SwiftClassItem.mul2(Swift.Int) -> Swift.Int",
            "SwiftHookTests.SwiftClassItem.add2(Swift.Int) -> Swift.Int",
            for: SwiftClassItem.self
        )

        print(item.add2(5))
        XCTAssertEqual(item.add2(5), 10)
    }

    func testExchangeObjCClassMethod() throws {
        let item = ObjCClassItem()
        print(item.add2(5))
        XCTAssertEqual(item.add2(5), 7)

        try SwiftHook.exchangeMethodImplementation(
            "mul2:",
            "add2:",
            for: ObjCClassItem.self
        )

        print(item.add2(5))
        XCTAssertEqual(item.add2(5), 10)
    }
}

// ref: https://github.com/johnno1962/Fortify/blob/1473a1c4e35c4fbb3a5c5c70563e7721964b91a1/Sources/Fortify.swift#L99
let disableExclusivityChecking: () = {
    if let stdlibHandle = dlopen(nil, Int32(RTLD_LAZY | RTLD_NOLOAD)),
       let disableExclusivity = dlsym(stdlibHandle, "_swift_disableExclusivityChecking") {
        disableExclusivity.assumingMemoryBound(to: Bool.self).pointee = true
    }
    else {
        NSLog("Could not disable exclusivity, failure likely...")
    }
}()
