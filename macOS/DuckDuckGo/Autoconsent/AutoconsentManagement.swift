//
//  AutoconsentManagement.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
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
import AppKit
import WebKit

final class AutoconsentManagement {
    static let shared = AutoconsentManagement()

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.installAutoconsentExtension()
        }
    }

    var sitesNotifiedCache = Set<String>()

    var pixelCounter = [String: Int]()

    var detectedByPatternsCache = Set<String>()
    var detectedByBothCache = Set<String>()
    var detectedOnlyRulesCache = Set<String>()

    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        sitesNotifiedCache.removeAll()
        detectedByPatternsCache.removeAll()
        detectedByBothCache.removeAll()
        detectedOnlyRulesCache.removeAll()
    }

    @MainActor
    func installAutoconsentExtension() {
        if #available(macOS 15.4, *),
           let webExtensionManager = NSApp.delegateTyped.webExtensionManager {
            let extensionPath = "file:///Users/sammacbeth/code/autoconsent/dist/addon-mv3"
            // Only install if not already installed
            if !webExtensionManager.webExtensionPaths.contains(extensionPath) {
                Task {
                    await webExtensionManager.installExtension(path: extensionPath)
                }
            }
            guard let context = webExtensionManager.loadedExtensions.first else {
                return
            }
        }
    }

}

@available(macOS 15.4, *)
final class AutoconsentNativeMessagingHandler: NativeMessagingHandling {

    static let newSitePopupHiddenNotification = Notification.Name("newSitePopupHidden")

    @MainActor
    func handleMessage(_ message: Any, to applicationIdentifier: String?, for extensionContext: WKWebExtensionContext) async throws -> Any? {
        switch applicationIdentifier {
        case "showAnimation":
            if let message = message as? [String: String], let url = message["url"] {
                NotificationCenter.default.post(name: Self.newSitePopupHiddenNotification, object: self, userInfo: [
                    "topUrl": url,
                    "isCosmetic": false
                ])
                return true
            }
            return false
        case "test":
            print("xxx Test message received")
            return nil
        default:
            return nil
        }
//        if let message = message as? [String: Any] {
//            print("xxx \(String(describing: applicationIdentifier))")
//
//        }
    }

    func handleConnection(using port: WKWebExtension.MessagePort, for extensionContext: WKWebExtensionContext) throws {
    }

}
