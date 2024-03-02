import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StaticArrayMacro: DeclarationMacro, MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        do {
            return try expansion(of: node, attachedTo: declaration, providingExtensionsOf: type)
        } catch is ExpansionError {
            /// Ignore the validation error thrown from one of the attached macro invokations.
            /// They both do validation, but only one error message is sufficient, so let's
            /// leave `providingMembersOf:` error repors as-is, and ignore `providingExtensionsOf:`
            return []
        }
    }
        
    private static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol
    ) throws -> [ExtensionDeclSyntax] {
        let structDecl = try asStructDecl(fromDeclarationGroup: declaration)
        let typeName = structDecl.name.trimmed
        let count = try count(fromAttributeArguments: node.arguments)
        let elementType = try elementType(fromAttributeName: node.attributeName)
        
        return [
            try ExtensionDeclSyntax("extension \(typeName): UnsafeStaticArrayProtocol") {
                """
                typealias Element = \(elementType)
                
                enum Index: Int, CaseIterable {
                    case \(indexCaseElements(count: count))
                }
                """
            },
            try ExtensionDeclSyntax("extension \(typeName): CustomStringConvertible") {
                """
                var description: String {
                    \(descriptionStringLiteral(count: count))
                }
                """
            },
            try ExtensionDeclSyntax("extension \(typeName): ExpressibleByArrayLiteral") {
                """
                typealias ArrayLiteralElement = \(elementType)
                \(arrayLiteralInit(elementType: elementType, count: count, typeName: typeName))
                """
            }
        ]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try providingErrorDiagnostic(in: context) {
            try expansion(of: node, providingMembersOf: declaration)
        }
    }
        
    private static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax
    ) throws -> [DeclSyntax] {
        let structDecl = try asStructDecl(fromDeclarationGroup: declaration)
        let typeName = structDecl.name.trimmed
        let count = try count(fromAttributeArguments: node.arguments)
        let elementType = try elementType(fromAttributeName: node.attributeName)
        let arrayType = arrayType(of: elementType, count: count)

        return ["""
        var staticArrayStorage: \(arrayType)
        
        init(_ repr: \(arrayType)) {
            self.staticArrayStorage = repr
        }
        
        init(repeating element: \(elementType)) {
            self.staticArrayStorage = \(tupleConstructor(argumentNames: repeatElement(TokenSyntax.identifier("element"), count: count)))
        }
        
        \(sequenceInit(elementType: elementType, count: count, typeName: typeName))
        
        init(from sequence: some Sequence<\(elementType)>, fillingMissingWith defaultValue: \(elementType)) {
            var iter = sequence.makeIterator()
            self.staticArrayStorage = \(tupleConstructorOfIterNextsWithDefaults(count: count))
        }
        
        \(exactlySizedSequenceInit(elementType: elementType, count: count, typeName: typeName))
        """]
    }
    
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try providingErrorDiagnostic(in: context) {
            try expansion(of: node)
        }
    }
    
    private static func expansion(of node: some FreestandingMacroExpansionSyntax) throws -> [DeclSyntax] {
        let typeName = try typeName(fromArgumentList: node.argumentList)
        let count = try count(fromArgumentList: node.argumentList)
        let elementType = try elementType(fromGenericArgumentClause: node.genericArgumentClause)
        let arrayType = arrayType(of: elementType, count: count)
        let initArgNames = identifierList(count: count, prefix: "v")
        
        return ["""
        struct \(typeName): UnsafeStaticArrayProtocol, ExpressibleByArrayLiteral, CustomStringConvertible {
            var staticArrayStorage: \(arrayType)
        
            typealias Element = \(elementType)
        
            init(_ repr: \(arrayType)) {
                self.staticArrayStorage = repr
            }
        
            init(\(functionArgList(argumentNames: initArgNames, elementType: elementType))) {
                self.staticArrayStorage = \(tupleConstructor(argumentNames: initArgNames))
            }
        
            init(repeating element: \(elementType)) {
                self.staticArrayStorage = \(tupleConstructor(argumentNames: repeatElement(TokenSyntax.identifier("element"), count: count)))
            }
        
            \(sequenceInit(elementType: elementType, count: count, typeName: typeName))
        
            init(from sequence: some Sequence<\(elementType)>, fillingMissingWith defaultValue: \(elementType)) {
                var iter = sequence.makeIterator()
                self.staticArrayStorage = \(tupleConstructorOfIterNextsWithDefaults(count: count, additionalIdentation: 4))
            }
        
            \(exactlySizedSequenceInit(elementType: elementType, count: count, typeName: typeName))
        
            enum Index: Int, CaseIterable {
                case \(indexCaseElements(count: count))
            }
        
            var description: String { \(descriptionStringLiteral(count: count)) }
        
            typealias ArrayLiteralElement = \(elementType)
            \(arrayLiteralInit(elementType: elementType, count: count, typeName: typeName))
        }
        """]
    }
}

public enum ExpansionError: CustomStringConvertible, Error {
    case invalidName, invalidCount(got: ExprSyntax?), noGenericType, attachedToANonStructType(keyword: TokenSyntax?)
    
    public var description: String {
        switch self {
        case .invalidName: "#StaticArray expected to receive an argument `named:` which should be a string literal"
        case .invalidCount(got: nil): "#StaticArray expected to receive an argument `count:` which should be a positive number literal"
        case .invalidCount(got: let got?): "Count of #StaticArray should be at least 2. Got \(got)"
        case .noGenericType: "#StaticArray requires setting an element type explicitly using swift's generics syntax, aka: #StaticArray<ElementType>(count: 5, named: \"MyArray\")"
        case .attachedToANonStructType(keyword: let keyword):
            if let plural = plural(ofTypeDeclKeyword: keyword?.tokenKind) {
                "@StaticArray can only be declared on the struct types, not \(plural)"
            } else {
                "@StaticArray can only be declared on the struct types"
            }
        }
    }
    
    var syntaxNode: (any SyntaxProtocol)? {
        switch self {
        case .invalidCount(got: let node):
            return node
        case .attachedToANonStructType(keyword: let node):
            return node
        default:
            return nil
        }
    }
}

func plural(ofTypeDeclKeyword keyword: TokenKind?) -> String? {
    switch (keyword) {
    case .keyword(.class): "classes"
    case .keyword(.enum): "enums"
    case .keyword(.actor): "actors"
    case .keyword(.struct): "structs"
    case .keyword(.extension): "extensions"
    case .keyword(.protocol): "protocols"
    default: nil
    }
}

func providingErrorDiagnostic<T>(
    in context: some MacroExpansionContext,
    _ body: () throws -> [T]
) rethrows -> [T] {
    do {
        return try body()
    } catch let error as ExpansionError {
        if let node = error.syntaxNode {
            context.addDiagnostics(from: error, node: node)
            return []
        } else {
            throw error
        }
    }
}

func count(fromArgumentList argList: LabeledExprListSyntax) throws -> Int {
    guard let countArg = argList
        .first(where: { $0.label?.text == "count" })?
        .expression
    else { throw ExpansionError.invalidCount(got: nil) }
    guard let countStr = countArg
        .as(IntegerLiteralExprSyntax.self)?
        .literal
        .text
    else { throw ExpansionError.invalidCount(got: countArg) }
    guard let count = Int(countStr)
    else { throw ExpansionError.invalidCount(got: countArg) }
    guard count > 1
    else { throw ExpansionError.invalidCount(got: countArg) }
    return count
}

func count(fromAttributeArguments arguments: AttributeSyntax.Arguments?) throws -> Int {
    guard let argList = arguments?.as(LabeledExprListSyntax.self) else {
        throw ExpansionError.invalidCount(got: nil)
    }
    return try count(fromArgumentList: argList)
}

func elementType(fromGenericArgumentClause clause: GenericArgumentClauseSyntax?) throws -> TypeSyntax {
    guard let elementType = clause?.arguments.first?.argument
    else { throw ExpansionError.noGenericType }
    return elementType
}

func elementType(fromAttributeName name: TypeSyntax) throws -> TypeSyntax {
    guard let genericClause = name.as(IdentifierTypeSyntax.self)?.genericArgumentClause
    else { throw ExpansionError.noGenericType }
    return try elementType(fromGenericArgumentClause: genericClause)
}

func arrayType(of elementType: TypeSyntax, count: Int) -> TupleTypeSyntax {
    return TupleTypeSyntax(elements: TupleTypeElementListSyntax {
        for (_, trivia) in withGap(0..<count) {
            TupleTypeElementSyntax(leadingTrivia: trivia, type: elementType)
        }
    })
}

func identifierList(count: Int, prefix: String) -> [TokenSyntax] {
    return (0..<count).map { TokenSyntax.identifier("\(prefix)\($0)") }
}

func withGap<Seq: Sequence>(_ items: Seq, inBetwee trivia: Trivia = .space) -> some Sequence<(item: Seq.Element, trivia: Trivia?)> {
    items.enumerated().map { (idx, item) in
        if idx == 0 { (item, nil) }
        else { (item, trivia) }
    }
}

func indexCaseElements(count: Int) -> EnumCaseElementListSyntax {
    return EnumCaseElementListSyntax {
        for (indexName, trivia) in withGap(identifierList(count: count, prefix: "i")) {
            EnumCaseElementSyntax(leadingTrivia: trivia, name: indexName)
        }
    }
}

func tupleConstructor(argumentNames: some Sequence<TokenSyntax>) -> TupleExprSyntax {
    return TupleExprSyntax {
        for (argName, trivia) in withGap(argumentNames) {
            LabeledExprSyntax(leadingTrivia: trivia, expression: DeclReferenceExprSyntax(baseName: argName))
        }
    }
}

func functionArgList(argumentNames: [TokenSyntax], elementType: TypeSyntax) -> FunctionParameterListSyntax {
    return FunctionParameterListSyntax {
        for argName in argumentNames {
            FunctionParameterSyntax(firstName: .wildcardToken(trailingTrivia: .space), secondName: argName, type: elementType)
        }
    }
}

func missingTuplePattern(bindingNames: [TokenSyntax]) -> TuplePatternSyntax {
    TuplePatternSyntax {
        for (name, trivia) in withGap(bindingNames) {
            TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("\(name)?"))
        }
    }
}

func sequenceInit(elementType: TypeSyntax, count: Int, typeName: TokenSyntax) -> DeclSyntax {
    let argNames = identifierList(count: count, prefix: "v")

    return """
    init(from sequence: some Sequence<\(elementType)>) {
        var iter = sequence.makeIterator()
        let items = \(tupleConstructorOfIterNexts(count: count))
        if case let \(missingTuplePattern(bindingNames: argNames)) = items {
            self.staticArrayStorage = \(tupleConstructor(argumentNames: argNames))
        } else {
            preconditionFailure("Couldn't construct \(typeName) from a sequnce, which contains less than \(raw: count) elements")
        }
    }
    """
}

func tupleConstructorOfIterNexts(count: Int) -> TupleExprSyntax {
    let leadingTrivia = Trivia(pieces: [.newlines(1), .spaces(8)])
    
    return TupleExprSyntax {
        for _ in 0..<count - 1 {
            LabeledExprSyntax(
                leadingTrivia: leadingTrivia,
                expression: ExprSyntax("iter.next()")
            )
        }
        LabeledExprSyntax(
            leadingTrivia: leadingTrivia,
            expression: ExprSyntax("iter.next()"),
            trailingTrivia: Trivia(pieces: [.newlines(1), .spaces(4)])
        )
    }
}

func tupleConstructorOfIterNextsWithDefaults(count: Int, additionalIdentation: Int = 0) -> TupleExprSyntax {
    let leadingTrivia = Trivia(pieces: [.newlines(1), .spaces(8 + additionalIdentation)])
    
    return TupleExprSyntax {
        for _ in 0..<count - 1 {
            LabeledExprSyntax(
                leadingTrivia: leadingTrivia,
                expression: ExprSyntax("iter.next() ?? defaultValue")
            )
        }
        LabeledExprSyntax(
            leadingTrivia: leadingTrivia,
            expression: ExprSyntax("iter.next() ?? defaultValue"),
            trailingTrivia: Trivia(pieces: [.newlines(1), .spaces(4 + additionalIdentation)])
        )
    }
}

func tuplePatternOfOptionalWildcards(count: Int) -> TuplePatternSyntax {
    TuplePatternSyntax {
        for (_, trivia) in withGap(0..<count) {
            TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("_?"))
        }
    }
}

func exactlySizedSequenceInit(elementType: TypeSyntax, count: Int, typeName: TokenSyntax) -> DeclSyntax {
    let variableNames = identifierList(count: count, prefix: "v")
    
    let fromExactSeqInitExactPattern = TuplePatternSyntax {
        for (name, trivia) in withGap(variableNames) {
            TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("\(name)?"))
        }
        TuplePatternElementSyntax(
            leadingTrivia: .space,
            pattern: ExpressionPatternSyntax(
                expression: NilLiteralExprSyntax()
            )
        )
    }
    
    return """
    init(fromExactlySized sequence: some Sequence<\(elementType)>) {
        var iter = sequence.makeIterator()
        let items = \(tupleConstructorOfIterNexts(count: count + 1))
        switch items {
        case let \(fromExactSeqInitExactPattern):
            self.staticArrayStorage = \(tupleConstructor(argumentNames: variableNames))
        case \(tuplePatternOfOptionalWildcards(count: count + 1)):
            preconditionFailure("Couldn't construct \(typeName) from an exactly sized sequence, which contains more than \(raw: count) elements")
        default:
            preconditionFailure("Couldn't construct \(typeName) from an exactly sized sequnce, which contains less than \(raw: count) elements")
        }
    }
    """
}

func asStructDecl(fromDeclarationGroup decl: some DeclGroupSyntax) throws -> StructDeclSyntax {
    if case let structDecl as StructDeclSyntax = decl {
        return structDecl
    }
    
    let invalidKeyword: TokenSyntax? = switch decl {
    case let enumDecl as EnumDeclSyntax: enumDecl.enumKeyword
    case let classDecl as ClassDeclSyntax: classDecl.classKeyword
    case let protocolDecl as ProtocolDeclSyntax: protocolDecl.protocolKeyword
    case let extensionDecl as ExtensionDeclSyntax: extensionDecl.extensionKeyword
    case let actorDecl as ActorDeclSyntax: actorDecl.actorKeyword
    default: nil
    }
    throw ExpansionError.attachedToANonStructType(keyword: invalidKeyword)
}

func descriptionStringLiteral(count: Int) -> StringLiteralExprSyntax {
    let descriptionSegments = StringLiteralSegmentListSyntax {
        StringSegmentSyntax(content: .stringSegment("["))
        ExpressionSegmentSyntax {
            LabeledExprSyntax(expression: ExprSyntax("staticArrayStorage.0"))
        }
        for i in 1..<count {
            StringSegmentSyntax(content: .stringSegment(", "))
            ExpressionSegmentSyntax {
                LabeledExprSyntax(expression: ExprSyntax("staticArrayStorage.\(raw: i)"))
            }
        }
        StringSegmentSyntax(content: .stringSegment("]"))
    }
    return StringLiteralExprSyntax(
        openingQuote: .stringQuoteToken(),
        segments: descriptionSegments,
        closingQuote: .stringQuoteToken()
    )
}

func tupleConstructorFromCollection(base: TokenSyntax, count: Int) -> TupleExprSyntax {
    return TupleExprSyntax {
        for i in 0..<count {
            LabeledExprSyntax(expression: ExprSyntax("\(base)[\(literal: i)]"))
        }
    }
}

func arrayLiteralInit(elementType: TypeSyntax, count: Int, typeName: TokenSyntax) -> DeclSyntax {
    return """
    init(arrayLiteral elements: \(elementType)...) {
        precondition(elements.count == \(literal: count), "Type \(typeName) (#StaticArray) can only be initialized with array literals with exact size of \(literal: count). Got a literal with \\(elements.count) elements")
        self.staticArrayStorage = \(tupleConstructorFromCollection(base: "elements", count: count))
    }
    """
}

func typeName(fromArgumentList argList: LabeledExprListSyntax) throws -> TokenSyntax {
    guard let nameStr = argList
        .first(where: { $0.label?.text == "named" })?
        .expression
        .as(StringLiteralExprSyntax.self)?
        .representedLiteralValue
    else { throw ExpansionError.invalidName }
    
    return TokenSyntax.identifier(nameStr)
}

@main
struct StaticArrayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StaticArrayMacro.self
    ]
}
