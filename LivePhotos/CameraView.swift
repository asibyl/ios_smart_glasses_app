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
    @State private var showingImageViewer = false
    @State private var showingAnalysis = false
    @State private var selectedAnalysisType = "General"
    
    let analysisTypes = ["General", "Objects", "Landmarks", "Food", "Books"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                VStack(spacing: 10) {
                    HStack {
                        Circle()
                            .fill(bleReceiver.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(bleReceiver.isConnected ? "Connected" : "Not Connected")
                            .font(.headline)
                    }
                    
                    Text(bleReceiver.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Progress Bar (shown during transfer)
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
                            .onTapGesture {
                                showingImageViewer = true
                            }
                        
                        Text("Tap to view full size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Analysis
                        VStack(spacing: 10) {
                            VStack(spacing: 8) {
                                Picker("Analysis Type", selection: $selectedAnalysisType) {
                                    ForEach(analysisTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                
                                Button(action: { analyzeCurrentPhoto()}) {
                                    HStack {
                                        if aiAnalyzer.isAnalyzing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "brain.head.profile")
                                        }
                                        Text(aiAnalyzer.isAnalyzing ? "Analyzing..." : "Analyze")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    
                                }
                                .disabled(aiAnalyzer.isAnalyzing)
                            } // Analysis VStack
                            
                            if let error = aiAnalyzer.error {
                                Text("Error: \(error.localizedCapitalized)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    
                            }
                        } // Analysis VStack
                        .padding(.top, 10)
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
                
                // Action Buttons
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
                        /*
                        Button(action: {
                            bleReceiver.capturePhoto()
                        }) {
                            HStack {
                                Image(systemName: "camera.shutter.button")
                                Text("Capture Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }*/
                        
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
                } // VStack Actions
                .padding(.horizontal)
                .padding(.bottom)
            } // VStack
            .padding()
            .navigationTitle("Live Photos")
            .sheet(isPresented: $showingImageViewer) {
                ImageViewerSheet(image: bleReceiver.receivedImage)
            }
            .sheet(isPresented: $showingAnalysis) {
                AnalysisResultSheet(
                    result: aiAnalyzer.analysisResult,
                    analysisType: selectedAnalysisType
                )
            }
            .onReceive(aiAnalyzer.$analysisResult) { result in
                if !result.isEmpty {
                    showingAnalysis = true
                }
            }
        } // Nav View
    } // body
    
    private func analyzeCurrentPhoto() {
        guard let image = bleReceiver.receivedImage else { return }
        switch selectedAnalysisType {
            case "Objects":
                aiAnalyzer.identifyObject(image)
            case "Landmarks":
                aiAnalyzer.identifyLandmark(image)
            case "Food":
                aiAnalyzer.identifyFood(image)
            case "Text":
                aiAnalyzer.readText(image)
            case "Books":
                aiAnalyzer.identifyBook(image)
            default:
                aiAnalyzer.getDetailedDescription(image)
        }
    }
} // Camera




struct ImageViewerSheet: View {
    let image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
}



// Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
