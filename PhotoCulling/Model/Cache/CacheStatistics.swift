//
//  CacheStatistics.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

import Foundation

struct CacheStatistics {
    let hits: Int
    let misses: Int
    let evictions: Int
    let hitRate: Double
}
