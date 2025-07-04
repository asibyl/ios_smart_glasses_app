//
//  CameraView.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 6/29/25.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var bleReceiver = BLEPhotoReceiver()
    @StateObject private var aiAnalyzer = AIPhotoAnalyzer()
    @StateObject private var ttsManager = TTSManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                HStack { // Camera
                    Circle()
                        .fill(bleReceiver.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(bleReceiver.isConnected ? "Connected" : "Not Connected")
                            .font(.headline)
                    }
                    Spacer()
                    Text(bleReceiver.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                HStack { // Audio
                    Image(systemName: ttsManager.isUsingBluetoothAudio() ? "headphones.circle" : "speaker.wave.2")
                        .foregroundColor(ttsManager.isUsingBluetoothAudio() ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ttsManager.getCurrentAudioRoute())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    if ttsManager.isUsingBluetoothAudio() {
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Progress Bar (shown during photo transfer)
                if bleReceiver.transferProgress > 0 && bleReceiver.transferProgress < 1 {
                    VStack {
                        ProgressView(value: bleReceiver.transferProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("Transfer Progress: \(Int(bleReceiver.transferProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Image Display
                if let image = bleReceiver.receivedImage {
                    VStack {
                        Text("Latest Photo")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        
                    } // Image VStack
                    .padding()
                } else {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No photo received yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                }
                
                Spacer()
                
                // Camera Connection
                VStack(spacing: 15) {
                    if !bleReceiver.isConnected {
                        Button(action: {
                            bleReceiver.startScanning()
                        }) {
                            HStack {
                                if bleReceiver.isScanning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text(bleReceiver.isScanning ? "Scanning..." : "Scan for Camera")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(bleReceiver.isScanning)
                    } else {
                        Button(action: {
                            bleReceiver.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                Text("Disconnect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                } // Camera Connection VStack
                .padding(.horizontal)
                .padding(.bottom)
            } // VStack
            .padding()
            .navigationTitle("Live Photos")
            .onReceive(aiAnalyzer.$analysisResult) { result in
                if !result.isEmpty {
                    ttsManager.speak(result)
                }
            }
            .onReceive(bleReceiver.$receivedImage) { image in
                if image != nil {
                    aiAnalyzer.analyzePhoto(image!)
                }
            }
        } // Nav View
    } // body
} // Camera


// Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
