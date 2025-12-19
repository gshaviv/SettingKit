import Foundation
import Observation

@attached(member, names: named(_$observationRegistrar), named(_$defaults), named(init()), arbitrary)
@attached(extension, conformances: Observation.Observable, Sendable)
@attached(memberAttribute)
public macro AppSettings(defaults: UserDefaults = .standard, createBindings: Bool = true, createPublishers: Bool = true) = #externalMacro(module: "SettingMacros", type: "AppSettingMacro")

/// Marks a property as a setting.
/// 
/// Properties decorated with `@Setting` will generate the standard getter and setter,
/// and additionally a property named `$propertyName` exposing a `Binding` to that property,
/// allowing observation and two-way binding.
@attached(accessor)
public macro _Setting() = #externalMacro(module: "SettingMacros", type: "SettingMacro")


@attached(peer)
public macro Default(key: String) = #externalMacro(module: "SettingMacros", type: "DefaultValueMacro")
