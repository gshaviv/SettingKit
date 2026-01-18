import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SettingMacros)
  import SettingMacros

  let testMacros: [String: Macro.Type] = [
    "AppSettings": AppSettingMacro.self,
    "_Setting": SettingMacro.self,
    "Default": DefaultValueMacro.self,
  ]
#endif

final class MacrosTests: XCTestCase {
  func testMacro() throws {
    #if canImport(SettingMacros)
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

            static let shared = AppDefaults()

            private let _$defaults = defaults

            private init() {
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: RawRepresentable  {
              let data = _$defaults.value(forKey: key)
              if let typedData = data as? T.RawValue, let value = T(rawValue: typedData) {
                return value
              } else {
                return nil
              }
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: Codable {
              let data = _$defaults.data(forKey: key)
              if let data, let decoded = try? JSONDecoder().decode(type, from: data) {
                return decoded
              } else {
                return nil
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: Codable {
              if let data = try? JSONEncoder().encode(value) {
                _$defaults.set(data, forKey: key)
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: RawRepresentable  {
              _$defaults.set(value.rawValue, forKey: key)
            }

            private let _$observationRegistrar = Observation.ObservationRegistrar()

            var $delayMinutes: Binding<Double?> {
              let safeSelf = self
              return Binding {
                safeSelf.delayMinutes
              } set: {
                safeSelf.delayMinutes = $0
              }
            }

            lazy var $delayMinutesPublisher = PassthroughSubject<Double?, Never>()

            var $diaMinutes: Binding<Double > {
              let safeSelf = self
              return Binding {
                safeSelf.diaMinutes
              } set: {
                safeSelf.diaMinutes = $0
              }
            }

            lazy var $diaMinutesPublisher = PassthroughSubject<Double , Never>()

            var $peakMinutes: Binding<Double > {
              let safeSelf = self
              return Binding {
                safeSelf.peakMinutes
              } set: {
                safeSelf.peakMinutes = $0
              }
            }

            lazy var $peakMinutesPublisher = PassthroughSubject<Double , Never>()
        }

        extension AppDefaults: Observation.Observable, @unchecked Sendable {
        }
        """,
        macros: testMacros
      )
    #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testSettingExpansion() throws {
    var macros = testMacros
    macros["_Setting"] = nil
    #if canImport(SettingMacros)
      assertMacroExpansion(
        """
        @AppSettings(defaults, swiftUISupport: .none, createPublishers: false)
        class AppDefaults {
          var delayMinutes: Double?
          var diaMinutes: Double = 210
          var peakMinutes: Double = 90
        }
        """,
        expandedSource:
        """

        class AppDefaults {
          @_Setting(swiftUISupport: .none, createPublishers: false)
          var delayMinutes: Double?
          @_Setting(swiftUISupport: .none, createPublishers: false) 
          var diaMinutes: Double = 210
          @_Setting(swiftUISupport: .none, createPublishers: false) 
          var peakMinutes: Double = 90

            static let shared = AppDefaults()

            private let _$defaults = defaults

            private init() {
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: RawRepresentable  {
              let data = _$defaults.value(forKey: key)
              if let typedData = data as? T.RawValue, let value = T(rawValue: typedData) {
                return value
              } else {
                return nil
              }
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: Codable {
              let data = _$defaults.data(forKey: key)
              if let data, let decoded = try? JSONDecoder().decode(type, from: data) {
                return decoded
              } else {
                return nil
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: Codable {
              if let data = try? JSONEncoder().encode(value) {
                _$defaults.set(data, forKey: key)
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: RawRepresentable  {
              _$defaults.set(value.rawValue, forKey: key)
            }
        }

        extension AppDefaults: Observation.Observable, @unchecked Sendable {
        }
        """,
        macros: macros
      )
    #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testArguments() throws {
    #if canImport(SettingMacros)
      assertMacroExpansion(
        """
        @AppSettings(defaults, swiftUISupport: .none, createPublishers: false)
        class AppDefaults {
          var delayMinutes: Double?
          var diaMinutes: Double = 210
          var peakMinutes: Double = 90
        }
        """,
        expandedSource:
        """

        class AppDefaults {
          var delayMinutes: Double? {
              get {

                return _$defaults.object(forKey: "delayMinutes") as? Double
              }
              set {
                _$defaults.set(newValue, forKey: "delayMinutes")

              }
          }
          var diaMinutes: Double = 210 {
              get {

                return _$defaults.object(forKey: "diaMinutes") as? Double ?? 210
              }
              set {
                _$defaults.set(newValue, forKey: "diaMinutes")

              }
          }
          var peakMinutes: Double = 90 {
              get {

                return _$defaults.object(forKey: "peakMinutes") as? Double ?? 90
              }
              set {
                _$defaults.set(newValue, forKey: "peakMinutes")

              }
          }

            static let shared = AppDefaults()

            private let _$defaults = defaults

            private init() {
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: RawRepresentable  {
              let data = _$defaults.value(forKey: key)
              if let typedData = data as? T.RawValue, let value = T(rawValue: typedData) {
                return value
              } else {
                return nil
              }
            }

            private func readRawRepresentableOrCodable<T>(_ type: T.Type, key: String) -> T? where T: Codable {
              let data = _$defaults.data(forKey: key)
              if let data, let decoded = try? JSONDecoder().decode(type, from: data) {
                return decoded
              } else {
                return nil
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: Codable {
              if let data = try? JSONEncoder().encode(value) {
                _$defaults.set(data, forKey: key)
              }
            }

            private func writeRawRepresentableOrCodable<T>(value: T, key: String)  where T: RawRepresentable  {
              _$defaults.set(value.rawValue, forKey: key)
            }
        }

        extension AppDefaults: Observation.Observable, @unchecked Sendable {
        }
        """,
        macros: testMacros
      )
    #else
      throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
}
