// AppLanguageBundle.swift
// One place that answers "which language did the player pick?" for code that
// SwiftUI's environment can't reach.
//
// WHY: the LANGUAGE toggle in Settings writes "settings.language" (EN/ID) and
// GameFlowView turns that into `.environment(\.locale, …)`. Every SwiftUI
// `Text("…")` re-resolves through that, so it flips live. Plain Swift strings —
// `String(localized:)` in the view model, the verdict lines, and the stroked
// UIKit titles (START / DONE / CANCEL …) — never see that environment, so
// without help they'd resolve against the DEVICE language and stay English on
// an English phone. Passing `bundle: .app` points them at the chosen
// language's strings table instead.
//
// Usage: String(localized: "DONE", bundle: .app)

import Foundation

extension Bundle {
    /// The `.lproj` bundle for the language chosen in Settings (falls back to
    /// the main bundle, i.e. the device language, if that .lproj is missing).
    // ponytail: looked up per call, no cache — these fire on taps and verdicts,
    // not per frame. Cache it if a profile ever says otherwise.
    static var app: Bundle {
        let code = UserDefaults.standard.string(forKey: "settings.language") == "ID" ? "id" : "en"
        return main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? main
    }
}
