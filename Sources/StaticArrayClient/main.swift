import StaticArray

@StaticArray<UInt8>(count: 4)
struct IPv4 {}
@StaticArray<UInt8>(count: 16)
struct IPv6 {}

var addr: IPv4 = [127, 0, 0, 1]
addr.forEach { print($0) }
let humanReadable = addr.withUnsafeBuffer { buffer in
    buffer.map(String.init).joined(separator: ".")
}
addr[.i0] = 192
addr[1] = 168
print(addr)

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
