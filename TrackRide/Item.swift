//
//  Item.swift
//  TrackRide
//
//  Created by Darryl Cauldwell on 01/01/2026.
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
