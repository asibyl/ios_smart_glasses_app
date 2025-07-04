//
//  TTSManager.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 7/4/25.
//
import AVFoundation
import UIKit

@MainActor
class TTSManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isPlaying: Bool = false
    
    override init() {
        super.init()
        setupAudioSession()
        setupSynthesizer()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for playback with Bluetooth support
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
            )
            
            try audioSession.setActive(true)
            
            print("Audio session configured for Bluetooth playback")
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupSynthesizer() {
        synthesizer.delegate = self
    }
    
    func speak(_ text: String) {
        // Stop any current speech
        stop()
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("No text to speak")
            return
        }
        
        // Create utterance with simple defaults
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5 // Normal speed
        utterance.pitchMultiplier = 1.0 // Normal pitch
        utterance.volume = 1.0 // Full volume
        
        // Use default system voice
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Start speaking
        synthesizer.speak(utterance)
        isPlaying = true
        
        print("Started speaking: \(text.prefix(50))...")
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
            print("Speech stopped")
        }
    }
    
    func getCurrentAudioRoute() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
        var outputs: [String] = []
        for output in currentRoute.outputs {
            outputs.append(output.portName)
        }
        
        return outputs.joined(separator: ", ")
    }
    
    func isUsingBluetoothAudio() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
        return currentRoute.outputs.contains { output in
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
        }
        print("Speech started")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
        }
        print("Speech finished")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
        }
        print("Speech cancelled")
    }
}
