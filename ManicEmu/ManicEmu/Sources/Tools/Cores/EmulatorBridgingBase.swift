//
//  EmulatorBridgingBase.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/6.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class EmulatorBridgeBase: NSObject, EmulatorBridging {
    var gameURL: URL?
    
    let frameDuration: TimeInterval = 1/60.0
    
    var audioRenderer: (any DeltaCore.AudioRendering)?
    
    var videoRenderer: (any DeltaCore.VideoRendering)?
    
    var saveUpdateHandler: (() -> Void)?
    
    func start(withGameURL gameURL: URL) {
        
    }
    
    func stop() {
        
    }
    
    func pause() {
        
    }
    
    func resume() {
        
    }
    
    func runFrame(processVideo: Bool) {
        
    }
    
    func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        
    }
    
    func resetInputs() {
        
    }
    
    func saveSaveState(to url: URL) {
        
    }
    
    func loadSaveState(from url: URL) {
        
    }
    
    func saveGameSave(to url: URL) {
        
    }
    
    func loadGameSave(from url: URL) {
        
    }
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool {
        false
    }
    
    func resetCheats() {
        
    }
    
    func updateCheats() {
        
    }
    
    
}

/// Manic MP: analog stick positions kept per player.
///
/// Every bridge is a singleton that serves all connected controllers, and each
/// axis callback arrives on its own (left/right or up/down) and is sent to the
/// core together with the other axis's last value. One position for all players
/// meant player 2's x went out with player 1's y, and a release by one player
/// zeroed a component of the other's stick: two Bluetooth pads in Mario Party 4
/// both "cutting out" whenever both sticks moved at once. Keyed by player index;
/// a player who has never moved reads as centered. Only touched from the main
/// thread, where DeltaCore delivers controller input to the cores.
final class PlayerStickPositions {
    private var positions: [Int: CGPoint] = [:]
    
    subscript(playerIndex: Int) -> CGPoint {
        get { positions[playerIndex] ?? .zero }
        set { positions[playerIndex] = newValue }
    }
}
