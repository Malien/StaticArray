import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(StaticArrayMacros)
    import StaticArrayMacros

    private let testMacros: [String: Macro.Type] = [
        "StaticArray": StaticArrayMacro.self
    ]
#endif

final class AttachedTests: XCTestCase {
    func testIPv4() throws {
        #if canImport(StaticArrayMacros)
            assertMacroExpansion(
                """
                @StaticArray<UInt8>(count: 4)
                struct IPv4 {
                }
                """,
                expandedSource: """
                    struct IPv4 {

                        var staticArrayStorage: (UInt8, UInt8, UInt8, UInt8)

                        init(_ repr: (UInt8, UInt8, UInt8, UInt8)) {
                            self.staticArrayStorage = repr
                        }

                        init(from sequence: some Sequence<UInt8>) {
                            var iter = sequence.makeIterator()
                            let items = (
                                iter.next(),
                                iter.next(),
                                iter.next(),
                                iter.next()
                            )
                            if case let (v0?, v1?, v2?, v3?) = items {
                                self.staticArrayStorage = (v0, v1, v2, v3)
                            } else {
                                preconditionFailure("Couldn't construct IPv4 from a sequnce, which contains less than 4 elements")
                            }
                        }
                    
                        init(from sequence: some Sequence<UInt8>, fillingMissingWith defaultValue: UInt8) {
                            var iter = sequence.makeIterator()
                            self.staticArrayStorage = (
                                iter.next() ?? defaultValue,
                                iter.next() ?? defaultValue,
                                iter.next() ?? defaultValue,
                                iter.next() ?? defaultValue
                            )
                        }
                    
                        init(fromExactlySized sequence: some Sequence<UInt8>) {
                            var iter = sequence.makeIterator()
                            let items = (
                                iter.next(),
                                iter.next(),
                                iter.next(),
                                iter.next(),
                                iter.next()
                            )
                            switch items {
                            case let (v0?, v1?, v2?, v3?, nil):
                                self.staticArrayStorage = (v0, v1, v2, v3)
                            case (_?, _?, _?, _?, _?):
                                preconditionFailure("Couldn't construct IPv4 from an exactly sized sequence, which contains more than 4 elements")
                            default:
                                preconditionFailure("Couldn't construct IPv4 from an exactly sized sequnce, which contains less than 4 elements")
                            }
                        }
                    
                        enum Index: Int, CaseIterable {
                            case i0, i1, i2, i3
                        }
                    }
                    """,
                macros: testMacros
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    //    func testWrapper() throws {
    //        #if canImport(StaticArrayMacros)
    //        assertMacroExpansion(
    //            """
    //            #StaticArray<()>(count: 1, named: "VoidWrapper")
    //            """,
    //            expandedSource: """
    //            """,
    //            diagnostics: [
    //                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got 1", line: 1, column: 25)
    //            ],
    //            macros: testMacros
    //        )
    //        #else
    //        throw XCTSkip("macros are only supported when running tests for the host platform")
    //        #endif
    //    }

    //    func testZST() throws {
    //        #if canImport(StaticArrayMacros)
    //        assertMacroExpansion(
    //            """
    //            #StaticArray<Int>(count: 0, named: "ZST")
    //            """,
    //            expandedSource: """
    //            """,
    //            diagnostics: [
    //                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got 0", line: 1, column: 26)
    //            ],
    //            macros: testMacros
    //        )
    //        #else
    //        throw XCTSkip("macros are only supported when running tests for the host platform")
    //        #endif
    //    }
    //
    //    func testNegativeCount() throws {
    //        #if canImport(StaticArrayMacros)
    //        assertMacroExpansion(
    //            """
    //            #StaticArray<Int>(count: -1, named: "NegativeMass")
    //            """,
    //            expandedSource: """
    //            """,
    //            diagnostics: [
    //                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got -1", line: 1, column: 26)
    //            ],
    //            macros: testMacros
    //        )
    //        #else
    //        throw XCTSkip("macros are only supported when running tests for the host platform")
    //        #endif
    //    }
}
