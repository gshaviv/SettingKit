import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MacrosMacros)
  import MacrosMacros

  let testMacros: [String: Macro.Type] = [
    "AppSettings": AppSettingMacro.self,
    "_Setting": SettingMacro.self,
    "Default": DefaultValueMacro.self,
  ]
#endif

final class MacrosTests: XCTestCase {
  func testMacro() throws {
    #if canImport(MacrosMacros)
      assertMacroExpansion(
        """
        @AppSettings(defaults)
        class AppDefaults {
          var delayMinutes: Double?
          @Default(key: "key1") var diaMinutes: Double = 210
          @Default(value: "key2") var peakMinutes: Double = 90
        }
        """,
        expandedSource:
        """

        class AppDefaults {
          var delayMinutes: Double? {
              get {
                _$observationRegistrar.access(self, keyPath: \\.delayMinutes)
                return _$defaults.object(forKey: "delayMinutes") as? Double
              }
              set {
                _$observationRegistrar.withMutation(of: self, keyPath: \\.delayMinutes) {
                  _$defaults.set(newValue, forKey: "delayMinutes")
                }
                $delayMinutesPublisher.send(newValue)
              }
          }
          
          var diaMinutes: Double = 210 {
              get {
                _$observationRegistrar.access(self, keyPath: \\.diaMinutes)
                return _$defaults.object(forKey: "key1") as? Double ?? 210
              }
              set {
                _$observationRegistrar.withMutation(of: self, keyPath: \\.diaMinutes) {
                  _$defaults.set(newValue, forKey: "key1")
                }
                $diaMinutesPublisher.send(newValue)
              }
          }
          
          var peakMinutes: Double = 90 {
              get {
                _$observationRegistrar.access(self, keyPath: \\.peakMinutes)
                return _$defaults.object(forKey: "key2") as? Double ?? 90
              }
              set {
                _$observationRegistrar.withMutation(of: self, keyPath: \\.peakMinutes) {
                  _$defaults.set(newValue, forKey: "key2")
                }
                $peakMinutesPublisher.send(newValue)
              }
          }

            private let _$observationRegistrar = Observation.ObservationRegistrar()

            private let _$defaults = defaults

            init() {
            }

            var $delayMinutes: Binding<Double?> {
              let safeSelf = self
              return Binding {
                safeSelf.delayMinutes
              } set: {
                safeSelf.delayMinutes = $0
              }
            }

            lazy var $delayMinutesPublisher = CurrentValueSubject<Double?, Never>(delayMinutes)

            var $diaMinutes: Binding<Double > {
              let safeSelf = self
              return Binding {
                safeSelf.diaMinutes
              } set: {
                safeSelf.diaMinutes = $0
              }
            }

            lazy var $diaMinutesPublisher = CurrentValueSubject<Double , Never>(diaMinutes)

            var $peakMinutes: Binding<Double > {
              let safeSelf = self
              return Binding {
                safeSelf.peakMinutes
              } set: {
                safeSelf.peakMinutes = $0
              }
            }

            lazy var $peakMinutesPublisher = CurrentValueSubject<Double , Never>(peakMinutes)
        }

        extension AppDefaults: Observation.Observable {
        }
        """,
        macros: testMacros
      )
    #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
}
