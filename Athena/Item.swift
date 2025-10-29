//
//  Item.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/29/25.
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
