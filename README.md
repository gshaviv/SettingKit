# SettingsKit - Typo Safe User Defaults

SettingsKit is a set of Swift Macros that make using UserDefaults typo safe (no string constants) as well as type safe (no referring to a string default as a bool). It also plays nicely with SwiftUI triggering a view redraw when defaults affecting on screen views change, has bindings for all defaults making it easy to modify them via swiftUI and can create Combine publishers for all defaults making it possible to track changes from non SwiftUI code. Also using the SwiftUI AppStorage propoerty wrapper suffers from using string keys which is prone to typos.

## Usage

Just define a type with the defaults you want to store, e.g.:

```
import SettingsKit
import SwiftUI
import Combine

@AppSettings
class AppDefaults {
  var value: Double = 10
  var anohterValue: Double?
  var enableThis: Bool = false
  @Default(key: "__confidence") var confidence: Confidence = .unsure
}
```

This will create a `AppDefaults` type with a static `shared` property. The properties you define are the user defaults to store. They can be of any type supported by `UserDefaults` (i.e. plist types), or any `RawRepresentable` enum or any Codable type. 

The key used to store the value in `UserDefaults` is the same as the property name unless a `@Default(key: ...)` macro is provided to set a custom key.

By default the `@AppSettings` macro uses the `UserDefaults.standard` user defaults. If you want to use a different suite, you can pass it as a parameter to the macro, e.g.:

```
@AppSettings(defaults: otherSuite)
```

You need to import SwiftUI and Combine to the file because the macro adds support for SwiftUI by supporting the Observation frameork and creating bindings and creating publishers. This can be suppressed by:

```
@AppSettings(swiftUISupport: .none, createPublishers: false)
```

The `swiftUISupport` can be `.none`, in which case there is no swiftUI support and views will not be updated when the setting change, `.observable` in which case swiftUI views will be re-rendered when a value they depend on changes, or `.observableWithBindings` which makes it both observable and adds bindings as the property name with a `$` prefix so they can easily be modified from a SwiftUI view. In the case of `.observable` the file should import the `Observation` or `SwiftUI` frameworks, in the case of `.observableWithBindings` the `SwiftUI` framework needs to be imported.

The property can be a non optional value, in which case a default value must be provided. If it is optional, if the default wasn't set, nil is returned and it can be assigned a nil to remove the default.

You can use it as follows:

```
struct ContentView: View {
	var body: some View {
	Form {
		if AppDefaults.shared.enableThis {
			Picker("Prediction Confidence", selection: AppDefaults.shared.$confidence) {
				ForEach(Confidence.allCases) {
					Text($0.description)
					.tag($0)
				}
			}
		}
	}
}
```

In this code, the view will be redrawn whenever the enableThis propty is changed, anywhere in the app. The property name with a `$` prefix is the binding to that property. Similarly for each peroty a `$<property Name>Publisher` is also created which is a `PassthoughSubject` that emits the new value whenever the value of that property is changed.
