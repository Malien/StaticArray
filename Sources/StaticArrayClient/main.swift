import StaticArray

enum Net {
    #StaticArray<UInt8>(count: 4, named: "IPv4")
    #StaticArray<UInt8>(count: 16, named: "IPv6")
}

var addr: Net.IPv4 = [127, 0, 0, 1]
addr.forEach { print($0) }
let humanReadable = addr.withUnsafeBuffer { buffer in
    buffer.map(String.init).joined(separator: ".")
}
addr[.i0] = 192
addr[1] = 168
print(addr)
