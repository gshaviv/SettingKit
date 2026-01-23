import Foundation
import Observation


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

@attached(member, names: named(_$observationRegistrar), named(_$defaults), named(init()), arbitrary)
@attached(extension, conformances: Observation.Observable, Sendable)
@attached(memberAttribute)
public macro AppSettings(defaults: UserDefaults = .standard, options: SynthesixeSetting = [.binding, .publisher, .observation]) = #externalMacro(module: "SettingMacros", type: "AppSettingMacro")

/// Marks a property as a setting.
/// 
/// Properties decorated with `@_Setting` will generate the standard getter and setter,
/// and additionally a property named `$propertyName` exposing a `Binding` to that property,
/// allowing observation and two-way binding.
@attached(accessor)
public macro _Setting(options: SynthesixeSetting = [.observation, .binding, .publisher]) = #externalMacro(module: "SettingMacros", type: "SettingMacro")

@attached(peer)
public macro Default(key: String) = #externalMacro(module: "SettingMacros", type: "DefaultValueMacro")
