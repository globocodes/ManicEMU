//
//  UniversalScript.swift
//  ManicJIT-script
//
//  Created by Stossy11 on 20/3/2026.
//
import Foundation
import UIKit

#if SIDE_LOAD
/// `uname` machine id, e.g. `iPad13,16`.
private func hardwareIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
}

/// iOS 26+ only. TXM is A15+/M2+ (`iPhone`/`iPad` machine major >= 14).
/// Unparseable IDs stay PPL so we never brk on unknown hardware.
private func hasTXMSilicon() -> Bool {
    let id = hardwareIdentifier()
    let digits: Substring
    if id.hasPrefix("iPhone") {
        digits = id.dropFirst(6)
    } else if id.hasPrefix("iPad") {
        digits = id.dropFirst(4)
    } else {
        return false
    }
    guard let comma = digits.firstIndex(of: ","),
          let major = Int(digits[..<comma]) else {
        return false
    }
    return major >= 14
}

public extension ProcessInfo {
    var hasTXM: Bool {
        let v = operatingSystemVersion
        if v.majorVersion < 26 {
            Log.debug("[JIT Env] Device: Legacy machine=\(hardwareIdentifier())")
            return false
        }
        let result = hasTXMSilicon()
        Log.debug("[JIT Env] Device: \(result ? "TXM" : "PPL") machine=\(hardwareIdentifier())")
        return result
    }
}


@_silgen_name("BreakSendJITScript")
func BreakSendJITScript(_ script: UnsafePointer<CChar>!, _ length: size_t)

func handler(sig: Int32, info: UnsafeMutablePointer<siginfo_t>?, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let uc = context.bindMemory(to: ucontext_t.self, capacity: 1)
    uc.pointee.uc_mcontext.pointee.__ss.__pc += 4
    uc.pointee.uc_mcontext.pointee.__ss.__x.0 = 0
}

// here to stop app from crashing when app launched without JIT attached on 26 TXM
func JIT26BreakpointHandler() {
    var sa = sigaction()
    sa.sa_flags = SA_SIGINFO
    
    sa.__sigaction_u.__sa_sigaction = handler
    
    sigaction(SIGTRAP, &sa, nil)
}
#endif

func setupUniversalScript(gameType: GameType) {
#if SIDE_LOAD
    guard #available(iOS 19.0, *) else { return }
    guard ProcessInfo.processInfo.hasTXM else { return }
    
    JIT26BreakpointHandler()
    
    var script: String? = nil
    switch gameType {
    case ._3ds:
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
      """
    case .n64:
        // TXM uses core-side brk #0xf00d (universal.js). Stub leftover 0x69
        // so an old dynarec binary cannot call prepare_memory_region after detach.
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
          legacyCommands[0x69] = function(b) {};
      """
    default: return
    }
    
    guard let script else { return }
    
    BreakSendJITScript(script, script.count)
#endif
}

#if SIDE_LOAD
/// Asks StikDebug for JIT once per process launch, then reports the result when the app is active again.
enum JITAutoEnabler {
    private enum State {
        case idle, requested, finished
    }
    
    private static var state: State = .idle
    private static var isAppReady = false
    
    static var isEnabled: Bool {
        get { Settings.defalut.getExtraBool(key: ExtraKey.autoEnableJIT.rawValue) ?? true }
        set { Settings.defalut.updateExtra(key: ExtraKey.autoEnableJIT.rawValue, value: newValue) }
    }
    
    /// Database and root view controller are ready. launchedByURL: the app was started to open a game or a file, leave that launch alone.
    static func appDidBecomeReady(launchedByURL: Bool) {
        isAppReady = true
        if launchedByURL {
            state = .finished
            return
        }
        if ApplicationSceneDelegate.applicationScene?.activationState == .foregroundActive {
            proceed()
        }
    }
    
    static func sceneDidBecomeActive() {
        guard isAppReady else { return }
        proceed()
    }
    
    private static func proceed() {
        switch state {
        case .idle:
            //Only one attempt per process launch, whatever the outcome
            state = .finished
            guard isEnabled,
                  !LibretroCore.jitAvailable(),
                  UIApplication.shared.canOpenURL(R.URLs.EnableJITUrl) else { return }
            Log.debug("[JIT Env] Auto enable: open \(R.URLs.EnableJITUrl)")
            state = .requested
            UIApplication.shared.open(R.URLs.EnableJITUrl) { success in
                if !success {
                    state = .finished
                }
            }
        case .requested:
            state = .finished
            pollResult(remaining: 10)
        case .finished:
            break
        }
    }
    
    /// StikDebug may still be attaching when the app comes back, so check for 5 seconds before giving up.
    private static func pollResult(remaining: Int) {
        if LibretroCore.jitAvailable() {
            Log.debug("[JIT Env] Auto enable: success")
            UIView.makeToast(message: R.string.localizable.autoEnableJITSuccess())
        } else if remaining > 0 {
            DispatchQueue.main.asyncAfter(delay: 0.5) {
                pollResult(remaining: remaining - 1)
            }
        } else {
            Log.debug("[JIT Env] Auto enable: failed")
            UIView.makeToast(message: R.string.localizable.autoEnableJITFailed(), duration: 6)
        }
    }
}
#endif
