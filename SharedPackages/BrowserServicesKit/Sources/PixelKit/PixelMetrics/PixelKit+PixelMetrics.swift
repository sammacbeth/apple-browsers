//
//  PixelKit+PixelMetrics.swift
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

extension PixelKit {

    private static let lastExportTimeKeyPrefix = "pixel_metrics_last_export_"

    /// Returns the pixel metrics provider factory, configured with this PixelKit instance as sender.
    /// Creates the factory on first access. Returns nil if PixelKit.shared is nil.
    public static func pixelMeterProviderFactory() -> PixelMeterProviderFactory? {
        guard let shared = shared else { return nil }
        return shared.pixelMeterProviderFactory
    }

    /// Instance-level access for the shared factory (used when you have a PixelKit instance).
    public var pixelMeterProviderFactory: PixelMeterProviderFactory {
        Self.factoryLock.lock()
        defer { Self.factoryLock.unlock() }
        let key = ObjectIdentifier(self)
        if let existing = Self.factoryByInstance[key] {
            return existing
        }
        let factory = makePixelMeterProviderFactory()
        Self.factoryByInstance[key] = factory
        return factory
    }

    private static let factoryLock = NSLock()
    private static var factoryByInstance: [ObjectIdentifier: PixelMeterProviderFactory] = [:]

    /// Removes the cached factory for the given instance. Called from tearDown.
    static func clearPixelMetricsFactoryCache(for instance: PixelKit) {
        factoryLock.lock()
        factoryByInstance[ObjectIdentifier(instance)] = nil
        factoryLock.unlock()
    }

    private func makePixelMeterProviderFactory() -> PixelMeterProviderFactory {
        var attrs: [String: AttributeValue] = ["appVersion": AttributeValue(pixelMetricsAppVersion)]
        if let src = pixelMetricsSource {
            attrs["pixelSource"] = AttributeValue(src)
        }
        let resource = Resource(attributes: attrs)
        return PixelMeterProviderFactory(
            pixelSender: self,
            resource: resource,
            getLastExportTime: { [weak self] cadence in
                guard let self else { return nil }
                let key = Self.lastExportTimeKeyPrefix + cadence.rawValue
                return self.pixelMetricsDefaults.object(forKey: key) as? Date
            },
            setLastExportTime: { [weak self] cadence, date in
                guard let self else { return }
                let key = Self.lastExportTimeKeyPrefix + cadence.rawValue
                self.pixelMetricsDefaults.set(date, forKey: key)
            }
        )
    }
}
