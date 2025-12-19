//
//  MacroPlugin.swift
//
//
//  Created by Guy Shaviv on 03/12/2023.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SettingsKitPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    AppSettingMacro.self,
    SettingMacro.self,
    DefaultValueMacro.self,
  ]
}
