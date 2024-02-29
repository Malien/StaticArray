import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StaticArrayExpansionError: CustomStringConvertible, Error {
    case invalidName, invalidCount(got: ExprSyntax?), noGenericType
    
    public var description: String {
        switch self {
        case .invalidName:
            return "#StaticArray expected to receive an argument `named:` which should be a string literal"
        case .invalidCount(got: nil):
            return "#StaticArray expected to receive an argument `count:` which should be a positive number literal"
        case .invalidCount(got: let got?):
            return "Count of #StaticArray should be at least 2. Got \(got)"
        case .noGenericType:
            return "#StaticArray requires setting an element type explicitly using swift's generics syntax, aka: #StaticArray<ElementType>(count: 5, named: \"MyArray\")"
        }
    }
}

public struct StaticArrayMacro: DeclarationMacro {
    public static func expansion(
        of node: some SwiftSyntax.FreestandingMacroExpansionSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let nameStr = node.argumentList
            .first(where: { $0.label?.text == "named" })?
            .expression
            .as(StringLiteralExprSyntax.self)?
            .representedLiteralValue
        else { throw StaticArrayExpansionError.invalidName }
        let name = TokenSyntax.identifier(nameStr)
        
        guard let countArg = node.argumentList
            .first(where: { $0.label?.text == "count" })?
            .expression
        else { throw StaticArrayExpansionError.invalidCount(got: nil) }
        guard let count = countArg
            .as(IntegerLiteralExprSyntax.self)?
            .literal
            .text
            .toInt()
        else {
            context.addDiagnostics(from: StaticArrayExpansionError.invalidCount(got: countArg), node: countArg)
            return []
        }
        if count <= 1 {
            context.addDiagnostics(from: StaticArrayExpansionError.invalidCount(got: countArg), node: countArg)
            return []
        }
        
        guard let elementType = node.genericArgumentClause?.arguments.first?.argument
        else { throw StaticArrayExpansionError.noGenericType }
        
        let arrayType = TupleTypeSyntax(elements: TupleTypeElementListSyntax {
            for _ in 0..<count {
                TupleTypeElementSyntax(type: elementType)
            }
        })
        
        let arrayLiteralConstructor = TupleExprSyntax {
            for i in 0..<count {
                LabeledExprSyntax(expression: ExprSyntax("elements[\(literal: i)]"))
            }
        }
        
        let indices = (0..<count).map { TokenSyntax.identifier("i\($0)") }
        let indexCaseElements = EnumCaseElementListSyntax {
            for indexName in indices {
                EnumCaseElementSyntax(name: indexName)
            }
        }
        
        let initArgNames = (0..<count).map { TokenSyntax.identifier("v\($0)") }
        let arglist = FunctionParameterListSyntax {
            for argName in initArgNames {
                FunctionParameterSyntax(firstName: .wildcardToken(trailingTrivia: .space), secondName: argName, type: elementType)
            }
        }
        
        let initConstructor = TupleExprSyntax {
            for argName in initArgNames {
                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: argName))
            }
        }
        
        let descriptionSegments = StringLiteralSegmentListSyntax {
            StringSegmentSyntax(content: .stringSegment("["))
            ExpressionSegmentSyntax {
                LabeledExprSyntax(expression: ExprSyntax("repr.0"))
            }
            for i in 1..<count {
                StringSegmentSyntax(content: .stringSegment(", "))
                ExpressionSegmentSyntax {
                    LabeledExprSyntax(expression: ExprSyntax("repr.\(raw: i)"))
                }
            }
            StringSegmentSyntax(content: .stringSegment("]"))
        }
        let descritpionString = StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: descriptionSegments,
            closingQuote: .stringQuoteToken()
        )
        
        return ["""
        struct \(name): UnsafeStaticArrayProtocol, ExpressibleByArrayLiteral, CustomStringConvertible {
            var repr: \(arrayType)
        
            typealias Element = \(elementType)
        
            init(_ repr: \(arrayType)) {
                self.repr = repr
            }
        
            init(\(arglist)) {
                self.repr = \(initConstructor)
            }
        
            enum Index: Int, CaseIterable {
                case \(indexCaseElements)
            }
        
            var description: String { \(descritpionString) }
        
            typealias ArrayLiteralElement = \(elementType)
            init(arrayLiteral elements: \(elementType)...) {
                precondition(elements.count == \(literal: count), "Type \(name) (#StaticArray) can only be initialized with array literals with exact size of \(literal: count). Got a literal with \\(elements.count) elements")
                self.repr = \(arrayLiteralConstructor)
            }
        }
        """]
    }
}

extension String {
    func toInt() -> Int? { Int(self) }
}

@main
struct StaticArrayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StaticArrayMacro.self
    ]
}
