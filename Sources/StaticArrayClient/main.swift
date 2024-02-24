import StaticArray

enum Namespace {
    #StaticArray<UInt8>(count: 4, named: "IPv4")
    #StaticArray<()>(count: 1, named: "VoidWrapper")
    #StaticArray<Int>(count: 0, named: "ZST")
    #StaticArray<Int>(count: -1, named: "NegativeMass")
}
