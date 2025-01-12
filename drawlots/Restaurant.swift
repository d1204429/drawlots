//
//  Restaurant.swift
//  drawlots
//
//  Created by hobart on 2024/12/17.
//

import Foundation

struct Restaurant: Identifiable, Codable {
    let id: UUID
    let mapsUrl: String
    let rating: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case mapsUrl = "mapsUrl"
        case rating
    }
}
