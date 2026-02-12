//
//  PixelMetricReader.swift
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
import OpenTelemetryApi
import OpenTelemetrySdk

/// No-op producer used until the SDK registers a real one.
private struct EmptyMetricProducer: MetricProducer {
    func collectAllMetrics() -> [MetricData] { [] }
}

/// Metric reader that passes metrics to the exporter only when the collection duration has elapsed
/// since the last export. Uses stored last export time so frequency is correct after app restart.
public final class PixelMetricReader: MetricReader {

    private let exporter: MetricExporter
    private let collectionInterval: TimeInterval
    private let getLastExportTime: () -> Date?
    private let setLastExportTime: (Date) -> Void
    private let scheduleQueue = DispatchQueue(label: "com.duckduckgo.PixelMetricReader.schedule")
    private let scheduleTimer: DispatchSourceTimer
    private let producerLock = NSLock()
    private var metricProducer: MetricProducer = EmptyMetricProducer()
    private var isShutdown = false

    public init(
        exporter: MetricExporter,
        collectionInterval: TimeInterval,
        getLastExportTime: @escaping () -> Date?,
        setLastExportTime: @escaping (Date) -> Void
    ) {
        self.exporter = exporter
        self.collectionInterval = collectionInterval
        self.getLastExportTime = getLastExportTime
        self.setLastExportTime = setLastExportTime
        scheduleTimer = DispatchSource.makeTimerSource(flags: [], queue: scheduleQueue)
        scheduleTimer.setEventHandler { [weak self] in
            self?.tick()
        }
    }

    deinit {
        _ = shutdown()
        scheduleTimer.activate()
    }

    public func register(registration: CollectionRegistration) {
        if let producer = registration as? MetricProducer {
            producerLock.lock()
            metricProducer = producer
            producerLock.unlock()
            scheduleTimer.schedule(deadline: .now() + 30, repeating: 30)
            scheduleTimer.activate()
        }
    }

    public func forceFlush() -> ExportResult {
        tick()
        return .success
    }

    public func shutdown() -> ExportResult {
        isShutdown = true
        scheduleTimer.suspend()
        if !scheduleTimer.isCancelled {
            scheduleTimer.cancel()
            scheduleTimer.resume()
        }
        return exporter.shutdown()
    }

    public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
        exporter.getAggregationTemporality(for: instrument)
    }

    public func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
        exporter.getDefaultAggregation(for: instrument)
    }

    private func tick() {
        guard !isShutdown else { return }
        let now = Date()
        let last = getLastExportTime() ?? .distantPast
        guard now.timeIntervalSince(last) >= collectionInterval else { return }
        producerLock.lock()
        let producer = metricProducer
        producerLock.unlock()
        let metrics = producer.collectAllMetrics()
        guard !metrics.isEmpty else { return }
        _ = exporter.export(metrics: metrics)
        setLastExportTime(now)
    }
}
