//
//  PixelMetricExporter.swift
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
import os.log
import OpenTelemetryApi
import OpenTelemetrySdk

/// Converts OTel MetricData into pixel requests and sends them via the provided sender.
/// One pixel per instrumentation scope (scope name = pixel name); query params from
/// resource attributes and per-metric values (including histogram buckets).
public final class PixelMetricExporter: MetricExporter {

    private weak var pixelSender: AggregatedPixelSending?
    private let logger: os.Logger

    init(pixelSender: AggregatedPixelSending, logger: os.Logger = .init(subsystem: "PixelKit", category: "PixelMetrics")) {
        self.pixelSender = pixelSender
        self.logger = logger
    }

    public func export(metrics: [MetricData]) -> ExportResult {
        guard let pixelSender else {
            logger.error("Pixel sender not available, skipping export")
            return .failure
        }
        guard !metrics.isEmpty else {
            return .success
        }
        let grouped = Dictionary(grouping: metrics) { $0.instrumentationScopeInfo.name }
        for (scopeName, scopeMetrics) in grouped {
            var params = resourceAttributesToParams(scopeMetrics.first?.resource ?? Resource(attributes: [:]))
            for metric in scopeMetrics {
                addMetricToParams(&params, metric: metric)
            }
            if !params.isEmpty {
                pixelSender.fireAggregatedPixel(name: scopeName, parameters: params) { _, _ in }
            }
        }
        return .success
    }

    public func flush() -> ExportResult {
        .success
    }

    public func shutdown() -> ExportResult {
        .success
    }

    public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
        .delta
    }

    // MARK: - Encoding helpers

    private func resourceAttributesToParams(_ resource: Resource) -> [String: String] {
        var params: [String: String] = [:]
        for (key, value) in resource.attributes {
            params[key] = value.description
        }
        return params
    }

    private func addMetricToParams(_ params: inout [String: String], metric: MetricData) {
        switch metric.type {
        case .LongSum, .LongGauge:
            if let points = metric.data.points as? [LongPointData], let first = points.first {
                params[metric.name] = String(first.value)
            }
        case .DoubleSum, .DoubleGauge:
            if let points = metric.data.points as? [DoublePointData], let first = points.first {
                params[metric.name] = String(first.value)
            }
        case .Histogram:
            let histogramPoints = (metric.data.points as? [HistogramPointData]) ?? []
            for point in histogramPoints {
                for (index, boundary) in point.boundaries.enumerated() where index < point.counts.count {
                    let paramKey = "\(metric.name)_\(Int(boundary))"
                    params[paramKey] = String(point.counts[index])
                }
            }
        case .ExponentialHistogram, .Summary:
            break
        }
    }
}
