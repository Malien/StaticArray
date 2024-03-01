# StaticArray
A macro for emulating C-like static arrays in the swift language

While swift core team is busy implementing various language features, and [fixed-size arrays aren't a thing yet](https://forums.swift.org/t/approaches-for-fixed-size-arrays/58894), here's the "polyfil" to add something similar in the meantime.

```swift
import StaticArray

@StaticArray<UInt8>(count: 4)
struct IPv4 {}
@StaticArray<UInt8>(count: 16)
struct IPv6 {}

var addr: IPv4 = [127, 0, 0, 1]
addr.forEach { 
    print($0)
}
let checksum = addr.reduce(0, +)
let isPrivate = addrs.starts(with: [192, 168])
let isLocal = addr.first == 127
let humanReadable = addr.withUnsafeBuffer { buffer in
    buffer.map(String.init).joined(separator: ".")
}
print(humanReadable) // "127.0.0.1"
addr[0] = 192
addr[.i1] = 168 // Indexing with IPv4.Index is always safe, and will never panic
addr.last = 255
print(addr[safe: 4]) // nil
print(addr) // [192, 168, 0, 255]
```

## Installation
Just shove 
```swift
.package(url: "https://github.com/malien/StaticArray.git", from: "1.0.0")
```
into the `dependencies` array of your Package.swift or via XCode's File->Add Package Dependency...

## Tradeoffs
### Why require an empty struct definition?
There actually previously was a different way of declaring static arrays:
```swift
enum Net {
    #StaticArray<UInt8>(count: 4, named: "IPv4")
}
``` 
There are drawbacks. The most notorious one being the requirement of a "namespace". Since the name is provided in the quotes, the macro required `@frestanding(..., names: arbitrary)`. And defining arbitrary names at the global level is disallowed by the swift compiler. With this namespacing requirement, declaring extensions on the type is not possible (as far as I know).

Another issue stemming from `names: arbitrary` is potential IDE performance, since the names are not declared upfront, the evaluation has to take place to resolve symbols.

This way of declaring arrays is still present (probably not for long) via the `#StaticArrayDecl` macro (overloading the same name as `@StaticArray` led to compilation issues, most likely due to the compiler bugs).

The declaration of `@StaticArray` on top of the struct, allows to more flexibly specify attributes like visibility (`private`, `public`, etc), other attributes (like `@frozen`), and providing additional members.

I don't recommend adding any stored members to the array type. This was the goal of the original `#StaticArrayDecl` macro, to prevent messing with the layout, and possible future blanket implementations of `Equatable`, `Comperable`, `Hashable`, `Codable`, etc.

### Why doesn't StaticArray conform to `Collection`?
It can't since it doesn't conform to `Sequence`

### Why doesn't StaticArray conform to `Sequence`?
Swit's structs are copied prevasively throughtout the exection of a program. In fact, structs are not guraranteed to be even materialized in memory at all. This is why taking pointers to them is a bit tricky. I require pointer trickery to implement iteration. Since the desire for static array is that they are embedded into the parent struct (or are allocated on the stack), doing persistent heap allocations is out of the picture. Pointers to structs are only valid inside of the `withUnsafe(Bytes|MutableBytes|Pointer|MutablePointer)` calls. Escaping pointers from those calls lead to undefined behaviour. As such, the package can only provide iteration inside of the `.withUnsafeBuffer` calls.

Don't worry too much, there is a couple of convenience methods on the StaticArray type itself, implemented via the `UnsafeStaticArrayProtocol` extension. As the name suggests, implementing `UnsafeStaticArrayProtocol` outside of the `#StaticArray` macro is unsafe.

If you need other methods like `.map` or `.filter`, one can use `.withUnsafeBuffer` to make all of the transformations inside of it. *BE CAREFUL!*: leaking the iterator to the outside is unsafe. Make sure the result of the transformation is collected into the intermediate owned value.

I'm also looking towards implementing things like `#staticMap(into:_:transform:)` to ease the pain a bit 

### Why isn't there a `Equatable`, `Comparable` or `Hashable` conformances?
Ideally user would be able to let the compiler provide the blanket implementation of `Equatable`, `Comparable`, etc like that:
```swift
@StaticArray<UInt8>(count: 4)
struct IPv4: Equatable {}
```

Unfortunately swift tuples don't conform to them, and the progress to make them is kinda stalled ([1](https://forums.swift.org/t/tuples-conform-to-equatable/32559), [2](https://github.com/apple/swift/pull/28833), [3](https://github.com/apple/swift/pull/34492), [4](https://forums.swift.org/t/tuples-conform-to-equatable-comparable-and-hashable/34156), [5](https://forums.swift.org/t/status-of-se-0283-tuples-conform-to-equatable-comparable-and-hashable/46942), [6](https://forums.swift.org/t/pitch-user-defined-tuple-conformances/67154), [7](https://forums.swift.org/t/type-int-cannot-conform-to-equatable/69125)). Since the storage for the elements is provided by tuples (via `staticArrayStorage` property), the issue affect the compiler's ability to synthesize implementations'.

For now the workaround is to provide a conformance like this:

```swift
@StaticArray<UInt8>(count: 4)
struct IPv4 {}

extension IPv4: Equatable {
    static func == (lhs: IPv4, rhs: IPv4) -> Bool {
        lhs.staticArrayStorage == rhs.staticArrayStorage
    }
}

extension IPv4: Comparable {
    static func < (lhs: IPv4, rhs: IPv4) -> Bool {
        lhs.staticArrayStorage < rhs.staticArrayStorage
    }
}

extension IPv4: Hashable {
    func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: staticArrayStorage) {
            hasher.combine(bytes: $0)
        }
    }
}
```

In the future I plan to add blanket implementations of these (if desired). This is why I would discourage adding stored properties to the type. I might prohibit it in the future (or might not). If you do desire to add a stored property, and have a `Equatable` conformance, just provide an extension yourself.

### Why isn't there a `Codable` conformance?
I don't think one can implement propper `Codable` without the knowledge that the underlying type also implements `Codable`. I just didn't get to it for now. 

Most likely it'll look like `@StaticArray<Int>(size: 32) struct MyArray: Codable {}`, with custom implementation shoved into the body.

#### Where are the benchmarks?
There are nowhere to be found. Sry. Have not yet gone into the weeds of measuring and optimizing the access patterns.
