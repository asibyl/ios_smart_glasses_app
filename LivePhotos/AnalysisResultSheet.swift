//
//  AnalysisResultSheet.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 6/30/25.
//

import SwiftUI

struct AnalysisResultSheet: View {
    let result: String
    let analysisType: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Analysis Type")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(analysisType)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Results")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(result)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .navigationTitle("AI Analysis")
        }
    }
}


