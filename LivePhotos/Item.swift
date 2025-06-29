//
//  Item.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 6/29/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
