# SwiftHook

A Swift Library for hooking swift methods and functions.

<!-- # Badges -->

[![Github issues](https://img.shields.io/github/issues/p-x9/swift-hook)](https://github.com/p-x9/swift-hook/issues)
[![Github forks](https://img.shields.io/github/forks/p-x9/swift-hook)](https://github.com/p-x9/swift-hook/network/members)
[![Github stars](https://img.shields.io/github/stars/p-x9/swift-hook)](https://github.com/p-x9/swift-hook/stargazers)
[![Github top language](https://img.shields.io/github/languages/top/p-x9/swift-hook)](https://github.com/p-x9/swift-hook/)

## How works

- **Function / Struct Method**
Hook by [facebook/fishhook](https://github.com/facebook/fishhook).

- **Objective-C Class Method**
Simply, Objective-C runtime is used.

- **Swift Class Method**
Hook by rewriting Vtable.

## Usage

### Function / Struct Method

> [!NOTE]
> To hook a function that exists in your own image, you must specify the following linker flag.  
> `"-Xlinker -interposable"`
>
> Reference: [johnno1962/SwiftTrace](https://github.com/johnno1962/SwiftTrace)

```swift
SwiftHook.exchangeFuncImplementation(
    "SwiftHookTests.StructItem.printA() -> Swift.String",
    "SwiftHookTests.StructItem.printB() -> Swift.String",
    isMangled: false
)

/* using mangled symbol names */
SwiftHook.exchangeFuncImplementation(
    "$s14SwiftHookTests21hook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAISus6UInt32VtF",
    "$s14SwiftHookTests25XXXXhook_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_A2ISus6UInt32VtF",
    isMangled: false
)
```

### Class Method

```swift
/// Swift Class
try SwiftHook.exchangeMethodImplementation(
    "SwiftHookTests.SwiftClassItem.mul2(Swift.Int) -> Swift.Int",
    "SwiftHookTests.SwiftClassItem.add2(Swift.Int) -> Swift.Int",
    for: SwiftClassItem.self
)

// Objective-C Class
try SwiftHook.exchangeMethodImplementation(
    "mul2:",
    "add2:",
    for: ObjCClassItem.self
)
```

## License

swift-hook is released under the MIT License. See [LICENSE](./LICENSE)
