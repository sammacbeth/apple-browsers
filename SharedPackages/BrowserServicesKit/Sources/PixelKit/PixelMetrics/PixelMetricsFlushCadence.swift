//
//  PixelMetricsFlushCadence.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this code except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// Aggregation cadence for pixel metrics. Determines how often metrics are collected and sent.
/// Distinct from PixelKit's `Frequency` (which controls per-pixel send rules like daily/unique).
public enum PixelMetricsFlushCadence: String, CaseIterable {
    /// Near-real-time (5 s flush interval).
    case instant = "instant"
    /// Short-window aggregation (10 min).
    case short = "short"
    /// Standard aggregated pixels (1 h).
    case hourly = "hourly"
    /// Low-frequency / summary (1 d).
    case daily = "daily"

    /// Flush interval in seconds.
    public var collectionInterval: TimeInterval {
        switch self {
        case .instant: return 5
        case .short: return 10 * 60
        case .hourly: return 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }
}
