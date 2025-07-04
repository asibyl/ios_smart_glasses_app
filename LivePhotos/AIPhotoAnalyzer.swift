//
//  AIPhotoAnalyzer.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 6/30/25.
//
import Foundation
import UIKit

class AIPhotoAnalyzer: ObservableObject {
    @Published var analysisResult: String = ""
    @Published var isAnalyzing: Bool = false
    @Published var error: String?
    
    private let openAIAPIKey = "TEST_MODE" // Replace with your API key
    
    func analyzePhoto(_ image: UIImage, prompt: String = "What do you see in this image? Describe the main objects and their details.") {
        guard !openAIAPIKey.isEmpty else {
            error = "Please set your OpenAI API key"
            return
        }
        
        isAnalyzing = true
        error = nil
        analysisResult = ""
        
        if openAIAPIKey == "TEST_MODE" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isAnalyzing = false
                self.analysisResult = "This is a test analysis result. The image appears to show a sample object for testing the audio playback functionality."
            }
            return
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            error = "Failed to convert image to data"
            isAnalyzing = false
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Prepare API request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-4o", // or "gpt-4-vision-preview"
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 300
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            self.error = "Failed to encode request: \(error.localizedDescription)"
            self.isAnalyzing = false
            return
        }
        
        // Make API call
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                
                if let error = error {
                    self?.error = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        self?.analysisResult = content
                        
                    } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                             let errorInfo = json["error"] as? [String: Any],
                             let errorMessage = errorInfo["message"] as? String {
                        
                        self?.error = "API Error: \(errorMessage)"
                        
                    } else {
                        self?.error = "Unexpected response format"
                        print("Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    }
                } catch {
                    self?.error = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    // Convenience methods for specific analysis types
    func identifyObject(_ image: UIImage) {
        analyzePhoto(image, prompt: "What is this object? Provide the name and key characteristics.")
    }
    
    func getDetailedDescription(_ image: UIImage) {
        analyzePhoto(image, prompt: "Describe what you see in this image. Be as specific as possible. ")
    }
    
    func readText(_ image: UIImage) {
        analyzePhoto(image, prompt: "Extract and transcribe any text visible in this image.")
    }
    
    func identifyFood(_ image: UIImage) {
        analyzePhoto(image, prompt: "If this is food, identify the dish, ingredients, and estimate nutritional information. If not food, say so.")
    }
    
    func identifyLandmark(_ image: UIImage) {
        analyzePhoto(image, prompt: "If this is a landmark, identify any notable features and history. If not a landmark, say so.")
    }
    
    func identifyBook(_ image: UIImage) {
        analyzePhoto(image, prompt: "If this is a book, write a summary and get its rating if possible. If not a book, say so.")
    }
}
