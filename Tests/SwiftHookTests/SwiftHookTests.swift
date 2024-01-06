import XCTest
import SwiftHook
import MachOKit

// ref: https://github.com/johnno1962/Fortify/blob/main/Sources/Fortify.swift

final class SwiftHookTests: XCTestCase {
    override class func setUp() {
        _ = disableExclusivityChecking
    }

    func testExchangeFunc() {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ XXXXhook_assertionFailure
        print(SwiftHook.exchangeFuncImplementation(
            "$s14SwiftHookTests21hook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
            "$s14SwiftHookTests25XXXXhook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2ISus6UInt32VtF",
            isMangled: false
        ))

        // XXXXhook_assertionFailure ⇔ _assertionFailure
        print(SwiftHook.exchangeFuncImplementation(
            "$s14SwiftHookTests25XXXXhook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2ISus6UInt32VtF",
            "$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2HSus6UInt32VtF",
            isMangled: true
        ))

        var optional: Int?
        let forceUnwrapped = optional!
    }

    func testExchangeDemangledFunc() {
        if setjump(&buf) != 0 {
            return
        }

        // XXXXhook_assertionFailure ⇔ _assertionFailure
        print(SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.XXXXhook_assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            "Swift._assertionFailure(_: Swift.StaticString, _: Swift.StaticString, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            isMangled: false
        ))

        var optional: Int?
        let forceUnwrapped = optional!
    }
}

extension SwiftHookTests {
    func testExchangeFuncInSelfImage() {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ XXXXhook_assertionFailure
        print(SwiftHook.exchangeFuncImplementation(
            "$s14SwiftHookTests21hook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
            "$s14SwiftHookTests25XXXXhook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
            isMangled: true
        ))

        hook_assertionFailure("aaa", "bbbb", flags: 0)
    }

    func testExchangeDemangledFuncInSelfImage() {
        if setjump(&buf) != 0 {
            return
        }

        // hook_assertionFailure ⇔ XXXXhook_assertionFailure
        print(SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.hook_assertionFailure(_: Swift.StaticString, _: Swift.String, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            "SwiftHookTests.XXXXhook_assertionFailure(_: Swift.StaticString, _: Swift.String, file: Swift.StaticString, line: Swift.UInt, flags: Swift.UInt32) -> Swift.Never",
            isMangled: false
        ))

        hook_assertionFailure("aaa", "bbbb", flags: 0)
    }
}

extension SwiftHookTests {
    func testExchangeStructFunction() {
        let item = StructItem()

        print(item.printA())
        print(item.printB())
        XCTAssertEqual(item.printA(), "A")
        XCTAssertEqual(item.printB(), "B")

        // printA ⇔ printB
        print(SwiftHook.exchangeFuncImplementation(
            "SwiftHookTests.StructItem.printA() -> Swift.String",
            "SwiftHookTests.StructItem.printB() -> Swift.String",
            isMangled: false
        ))

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
