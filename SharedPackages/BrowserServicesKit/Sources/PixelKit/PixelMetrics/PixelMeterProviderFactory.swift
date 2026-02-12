//
//  PixelMeterProviderFactory.swift
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

/// Factory that vends a MeterProvider per aggregation cadence. Each provider uses
/// PixelMetricExporter and a reader that only exports when the cadence interval has elapsed.
public final class PixelMeterProviderFactory {

    private let pixelSender: AggregatedPixelSending
    private let resource: Resource
    private let getLastExportTime: (PixelMetricsFlushCadence) -> Date?
    private let setLastExportTime: (PixelMetricsFlushCadence, Date) -> Void
    private var providers: [PixelMetricsFlushCadence: MeterProviderSdk] = [:]
    private let lock = NSLock()

    init(
        pixelSender: AggregatedPixelSending,
        resource: Resource,
        getLastExportTime: @escaping (PixelMetricsFlushCadence) -> Date?,
        setLastExportTime: @escaping (PixelMetricsFlushCadence, Date) -> Void
    ) {
        self.pixelSender = pixelSender
        self.resource = resource
        self.getLastExportTime = getLastExportTime
        self.setLastExportTime = setLastExportTime
    }

    /// Returns a MeterProvider for the given cadence. The same instance is returned for the same cadence.
    public func provider(for cadence: PixelMetricsFlushCadence) -> MeterProviderSdk {
        lock.lock()
        defer { lock.unlock() }
        if let existing = providers[cadence] {
            return existing
        }
        let exporter = PixelMetricExporter(pixelSender: pixelSender)
        let reader = PixelMetricReader(
            exporter: exporter,
            collectionInterval: cadence.collectionInterval,
            getLastExportTime: { [getLastExportTime, cadence] in getLastExportTime(cadence) },
            setLastExportTime: { [setLastExportTime, cadence] date in setLastExportTime(cadence, date) }
        )
        let provider = MeterProviderSdk.builder()
            .setResource(resource: resource)
            .registerMetricReader(reader: reader)
            .build()
        providers[cadence] = provider
        return provider
    }

    /// Convenience accessors for each cadence.
    public var instantProvider: MeterProviderSdk { provider(for: .instant) }
    public var shortProvider: MeterProviderSdk { provider(for: .short) }
    public var hourlyProvider: MeterProviderSdk { provider(for: .hourly) }
    public var dailyProvider: MeterProviderSdk { provider(for: .daily) }
}
