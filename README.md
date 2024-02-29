# StaticArray
A macro for emulating C-like static arrays in the swift language

```swift
import StaticArray

enum Net {
    #StaticArray<UInt8>(count: 4, named: "IPv4")
    #StaticArray<UInt8>(count: 16, named: "IPv6")
}

var addr: Net.IPv4 = [127, 0, 0, 1]
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
### Why doesn't StaticArray conform to `Collection`?
It can't since it doesn't conform to `Sequence`

### Why doesn't StaticArray conform to `Sequence`?
Swit's structs are copied prevasively throughtout the exection of a program. In fact, structs are not guraranteed to be even materialized in memory at all. This is why taking pointers to them is a bit tricky. I require pointer trickery to implement iteration. Since the desire for static array is that they are embedded into the parent struct (or are allocated on the stack), doing persistent heap allocations is out of the picture. Pointers to structs are only valid inside of the `withUnsafe(Bytes|MutableBytes|Pointer|MutablePointer)` calls. Escaping pointers from those calls lead to undefined behaviour. As such, the package can only provide iteration inside of the `.withUnsafeBuffer` calls.

Don't worry too much, there is a couple of convenience methods on the StaticArray type itself, implemented via the `UnsafeStaticArrayProtocol` extension. As the name suggests, implementing `UnsafeStaticArrayProtocol` outside of the `#StaticArray` macro is unsafe.

If you need other methods like `.map` or `.filter`, one can use `.withUnsafeBuffer` to make all of the transformations inside of it. BE CAREFUL!: leaking the iterator to the outside is unsafe. Make sure the result of the transformation is collected into the intermediate owned value.

### Why require a namespace for the defintion
This is a limitation of swift's macros. Arbitrary names can only be introduced in the namespace. And name is arbitrary since it is derived via the `named: "StructName"` parameter.

The next version of this package is likely to use different syntax for definitions, to allow the use outside of the namespace (and also to allow easy `Equatable`, `Hashable`, `Comperable`, etc.) conformance. It is also likely to improve the editor performance (no more `names: arbitrary`)

```swift
# Preview of future syntax
@StaticArray<UInt8>(count: 4)
struct IPv4: Equatable {}
```

### Why isn't there a `Codable` conformance?
I don't think one can implement propper `Codable` without the knowledge that the underlying type also implements `Codable`. I just didn't get to it for now. Most likely it'll look like `#StaticArray(count: 6, named: "Whatever", conformsToCodable: true)

#### Where are the benchmarks?
There are nowhere to be found. Sry. Have not yet gone into the weeds of measuring and optimizing the access patterns.
