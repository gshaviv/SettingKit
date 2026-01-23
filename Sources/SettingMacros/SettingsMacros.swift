import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SynthesixeSetting: OptionSet, Sendable, CustomStringConvertible {
  public let rawValue: Int
  
  public static let observation = SynthesixeSetting(rawValue: 1)
  public static let binding = SynthesixeSetting(rawValue: 1 << 1)
  public static let publisher = SynthesixeSetting(rawValue: 1 << 2)
  
  init(string: String) {
    self = []
    if string.contains("observation") {
      insert(.observation)
    }
    if string.contains("binding") {
      insert(.binding)
    }
    if string.contains("publisher") {
      insert(.publisher)
    }
  }
  
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  public var description: String {
    var components = [String]()
    if contains(.observation) {
      components.append(".observation")
    }
    if contains(.binding) {
      components.append(".binding")
    }
    if contains(.publisher) {
      components.append(".publisher")
    }
    return components.isEmpty ? "[]" : "[\(components.joined(separator: ","))]"
  }
}

public struct AppSettingMacro: MemberMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingMembersOf declaration: some DeclGroupSyntax,
                               in context: some MacroExpansionContext) throws -> [DeclSyntax]
  {
    guard declaration.kind == .classDecl else {
      context.diagnose(node: node, severity: .error, message: "Can only be applied to a class")
      return []
    }
    let args = node.extractArgs()
    let defaults = args.parse("", using: { $0 }) ?? "UserDefaults.standard"
    let options = args.parse("options", using: { SynthesixeSetting(string: $0.description) }) ?? [.binding, .observation, .publisher]
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      context.diagnose(node: node, severity: .error, message: "Can only be applied to a class")
      return []
    }
    let typeName = classDecl.name.text.trimmingCharacters(in: .whitespaces)
    
    var decls: [DeclSyntax] = [
      """
      static let shared = \(raw: typeName)()
      """,
      """
      private let _$defaults = \(defaults)
      """
    ]
    
    if classDecl.inheritanceClause == nil {
      decls.append("private init() {}")
    }
    
    decls.append(contentsOf: [
      """
      private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: RawRepresentable  {
        let data = _$defaults.value(forKey: key)
        if let typedData = data as? T.RawValue, let value = T(rawValue: typedData) {
          return value
        } else {
          return nil
        }
      }
      """,
      """
      private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: Codable {
        let data = _$defaults.data(forKey: key)
        if let data, let decoded = try? JSONDecoder().decode(type, from: data) {
          return decoded
        } else {
          return nil
        }
      }
      """,
      """
      private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: Codable {
        if let data = try? JSONEncoder().encode(value) {
          _$defaults.set(data, forKey: key)
        }
      }
      """,
      """
      private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: RawRepresentable  {
        _$defaults.set(value.rawValue, forKey: key)
      }
      """
    ])
    
    if options.contains(.observation) {
      decls.append(DeclSyntax("private let _$observationRegistrar = Observation.ObservationRegistrar()"))
    }

    // Iterate over variable members to generate binding properties for stored vars (no accessors)
    for member in declaration.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
      // Only generate binding for stored properties (no accessor block)
      var hasAccessor = false
      for binding in varDecl.bindings {
        guard binding.accessorBlock == nil else {
          hasAccessor = true
          break
        }
      }
      guard !hasAccessor else { continue }
      // For each binding in the variable declaration (usually one)
      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
        guard let type = binding.typeAnnotation?.type else { continue }
        let propertyName = pattern.identifier.text
        if options.contains(.binding) {
          decls.append(
          """
          var $\(raw: propertyName): Binding<\(type)> {
            let safeSelf = self
            return Binding {
              safeSelf.\(raw: propertyName)
            } set: {
              safeSelf.\(raw: propertyName) = $0
            }
          }
          """
          )
        }
        if options.contains(.publisher) {
          decls.append(
          """
          lazy var $\(raw: propertyName)Publisher = PassthroughSubject<\(type), Never>()
          """
          )
        }
      }
    }

    return decls
  }
}

extension AppSettingMacro: ExtensionMacro {
  public static func expansion(of _: AttributeSyntax, attachedTo _: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo _: [TypeSyntax], in _: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
    try [ExtensionDeclSyntax("extension \(type): Observation.Observable, @unchecked Sendable") {}]
  }
}

extension AppSettingMacro: MemberAttributeMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo _: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    // Only attach macro if member is a variable.
    // Otherwise, it will also get attached to the structs generated by @EnvironmentValue
    guard member.is(VariableDeclSyntax.self) else {
      return []
    }
    let args = node.extractArgs()
    let options = args.parse("options", using: { SynthesixeSetting(string: $0.description) })

    return [
      AttributeSyntax(atSign: .atSignToken(), attributeName: IdentifierTypeSyntax(name:  options == nil ? .identifier("_Setting") :  .identifier("_Setting(options: \(options?.description ?? ""))"))),
    ]
  }
}

public struct SettingMacro: AccessorMacro {
  public static func expansion(of node: AttributeSyntax,
                               providingAccessorsOf declaration: some DeclSyntaxProtocol,
                               in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax]
  {
    guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
      return []
    }
    guard let syntax = varDecl.bindings.as(PatternBindingListSyntax.self)?.first?.as(PatternBindingSyntax.self) else {
      return []
    }
    guard let type = syntax.typeAnnotation?.type.trimmed else {
      return []
    }
    let args = node.extractArgs()
    let options = args.parse("options", using: { SynthesixeSetting(string: $0.description) }) ?? [.publisher, .observation, .binding]
    let defaultValue = syntax.initializer?.value

    if type.kind != .optionalType && defaultValue == nil {
      context.diagnose(node: node, severity: .error, message: "Non-optional UserDefaults-backed properties must have a default value via initializer.")
      return []
    }
    
    let isOptional = type.is(OptionalTypeSyntax.self)
    let baseType = type.as(OptionalTypeSyntax.self)?.wrappedType ?? type
    guard let property = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed else {
      return []
    }
    
    var keyExpression: ExprSyntax? = nil
    if let element = varDecl.element(withIdentifier: "Default"), let defaultArgument = element.argument() {
      keyExpression = defaultArgument
    }
    let keyName = keyExpression?.description.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) ?? property.description


    // Decide if the baseType is a UserDefaults-primitive or container thereof
    let primitive = isUserDefaultsPrimitiveOrContainer(baseType)
    let propertyName = syntax.pattern.description

    if primitive {

      // Existing primitive path
      let getter: AccessorDeclSyntax =
      """
      get {
        \(!options.contains(.observation) ? "" : "_$observationRegistrar.access(self, keyPath: \\.\(property))")
        return _$defaults.object(forKey: "\(raw: keyName)") as? \(baseType)\(raw: defaultValue == nil ? "" : " ?? \(defaultValue!)")
      }
      """
      
      let setter: AccessorDeclSyntax =
      !options.contains(.observation) ?
      """
      set {
        _$defaults.set(newValue, forKey: "\(raw: keyName)")
       \(options.contains(.publisher) ? "$\(raw: propertyName)Publisher.send(newValue)" : "")
      }
      """ :
      """
      set {
        _$observationRegistrar.withMutation(of: self, keyPath: \\.\(property)) {
          _$defaults.set(newValue, forKey: "\(raw: keyName)")
        }
       \(options.contains(.publisher) ? "$\(raw: propertyName)Publisher.send(newValue)" : "")
      }
      """
      return [getter, setter]
    } else {
      // Codable-to-JSON path (syntax-based; assumes conformance)
      let getterBody: String
      if isOptional {
        getterBody =
        """
        return readRawRepresentableOrCodable(\(baseType).self, key: "\(keyName)")
        """
      } else {
        let defaultExpr = defaultValue?.description ?? "nil"
        getterBody =
        """
        return readRawRepresentableOrCodable(\(baseType).self, key: "\(keyName)") ?? \(defaultExpr)
        """
      }

      let setterBody: String
      if isOptional {
        setterBody =
        """
        if let newValue {
          writeRawRepresentableOrCodable(value: newValue, key: "\(keyName)")
        } else {
          _$defaults.removeObject(forKey: "\(keyName)")
        }
        """
      } else {
        setterBody =
        """
        writeRawRepresentableOrCodable(value: newValue, key: "\(keyName)")
        """
      }

      let getter: AccessorDeclSyntax =
      """
      get {
        \(!options.contains(.observation) ? "" : "_$observationRegistrar.access(self, keyPath: \\.\(property))")
        \(raw: getterBody)
      }
      """
      let setter: AccessorDeclSyntax =
      !options.contains(.observation) ?
      """
        set {
          \(raw: setterBody)
          \(options.contains(.publisher) ? "$\(raw: propertyName)Publisher.send(newValue)" : "")
        }
      """ :
      """
      set {
        _$observationRegistrar.withMutation(of: self, keyPath: \\.\(property)) {
          \(raw: setterBody)
        }
        \(options.contains(.publisher) ? "$\(raw: propertyName)Publisher.send(newValue)" : "")
      }
      """
      return [getter, setter]
    }
  }

  // MARK: - Type classification (syntax-only)

  private static func isUserDefaultsPrimitiveOrContainer(_ type: some TypeSyntaxProtocol) -> Bool {
    let t = TypeSyntax(type).trimmed
    if isPrimitiveIdentifier(t) { return true }
    if let arr = t.as(ArrayTypeSyntax.self) {
      return isUserDefaultsPrimitiveOrContainer(arr.element)
    }
    if let dict = t.as(DictionaryTypeSyntax.self) {
      // UserDefaults supports [String: Primitive]
      if let keyId = dict.key.as(IdentifierTypeSyntax.self),
         keyId.name.text == "String" {
        return isUserDefaultsPrimitiveOrContainer(dict.value)
      }
      return false
    }
    if let opt = t.as(OptionalTypeSyntax.self) {
      return isUserDefaultsPrimitiveOrContainer(opt.wrappedType)
    }
    if let ident = t.as(IdentifierTypeSyntax.self) {
      // Handle generic wrappers like Array<Primitive>, Dictionary<String, Primitive>
      if let generic = ident.genericArgumentClause {
        let name = ident.name.text
        if name == "Array", let first = generic.arguments.first?.argument {
          return isUserDefaultsPrimitiveOrContainer(first)
        }
        if name == "Dictionary", generic.arguments.count == 2 {
          let key = generic.arguments[generic.arguments.startIndex].argument
          let value = generic.arguments[generic.arguments.index(after: generic.arguments.startIndex)].argument
          if let keyId = key.as(IdentifierTypeSyntax.self), keyId.name.text == "String" {
            return isUserDefaultsPrimitiveOrContainer(value)
          }
        }
      }
      // Bare identifier already handled by isPrimitiveIdentifier
      return isPrimitiveIdentifier(ident)
    }
    return false
  }

  private static func isPrimitiveIdentifier(_ type: some TypeSyntaxProtocol) -> Bool {
    guard let ident = TypeSyntax(type).as(IdentifierTypeSyntax.self) else { return false }
    let name = ident.name.text
    // Common UserDefaults primitives
    let primitives: Set<String> = [
      "Bool", "Int", "Int8", "Int16", "Int32", "Int64",
      "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
      "Double", "Float", "String", "Data", "Date", "URL", "NSNumber", "NSArray", "NSDictionary"
    ]
    return primitives.contains(name)
  }
}

public struct DefaultValueMacro: PeerMacro {
  public static func expansion(of _: AttributeSyntax, providingPeersOf _: some DeclSyntaxProtocol, in _: some MacroExpansionContext) throws -> [DeclSyntax] {
    []
  }
}

struct Message: DiagnosticMessage, Hashable {
  var severity: DiagnosticSeverity
  var message: String

  var diagnosticID: MessageID {
    MessageID(domain: "Macros", id: "\(hashValue)")
  }
}

extension MacroExpansionContext {
  func diagnose(node: AttributeSyntax, severity: DiagnosticSeverity, message: String) {
    diagnose(Diagnostic(node: node, message: Message(severity: severity, message: message)))
  }
}

extension AttributeSyntax {
  func extractArgs() -> [String: ExprSyntax] {
    guard case let .argumentList(arguments) = arguments else {
      return [:]
    }
    return arguments.reduce(into: [String: ExprSyntax]()) {
      $0[$1.label?.trimmed.description ?? ""] = $1.expression.trimmed
    }
  }
}

extension [String: ExprSyntax] {
  func parse<T>(_ key: String, using block: (ExprSyntax) -> T?) -> T? {
    if let value = self[key] {
      return block(value)
    } else {
      return nil
    }
  }
}

private extension VariableDeclSyntax {
  func element(
    withIdentifier macroName: String
  ) -> AttributeListSyntax.Element? {
    attributes.first {
      $0.as(AttributeSyntax.self)?
        .attributeName
        .as(IdentifierTypeSyntax.self)?
        .description
        .trimmingCharacters(in: .whitespaces) == macroName
    }
  }
}

private extension AttributeListSyntax.Element {
  func argument() -> ExprSyntax? {
    self
      .as(AttributeSyntax.self)?
      .arguments?
      .as(LabeledExprListSyntax.self)?
      .first?
      .expression
  }
}

