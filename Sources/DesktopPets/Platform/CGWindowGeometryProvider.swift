import CoreGraphics
import Foundation

struct RawWindowRecord: Equatable, Sendable {
    let id: UInt32
    let ownerPID: Int32
    let layer: Int
    let alpha: Double
    let bounds: WorldRect
    let ownerName: String
    let isOnScreen: Bool
}

enum WindowFilter {
    private static let ignoredOwners: Set<String> = [
        "Dock", "Window Server", "SystemUIServer", "Control Center", "Notification Center",
    ]

    static func normalize(
        records: [RawWindowRecord],
        ownPID: Int32,
        mainScreenMaxY: Double,
        displayBounds: [WorldRect]
    ) -> [Obstacle] {
        records.compactMap { record in
            guard record.ownerPID != ownPID,
                  record.layer == 0,
                  record.alpha > 0.05,
                  record.isOnScreen,
                  record.bounds.width >= 80,
                  record.bounds.height >= 60,
                  !ignoredOwners.contains(record.ownerName),
                  let converted = WorldRect(
                      x: record.bounds.x,
                      y: mainScreenMaxY - record.bounds.y - record.bounds.height,
                      width: record.bounds.width,
                      height: record.bounds.height
                  ),
                  displayBounds.contains(where: { $0.intersects(converted) }) else { return nil }
            return Obstacle(id: "window-\(record.id)", kind: .window, rect: converted)
        }
        .sorted { $0.id < $1.id }
    }
}

@MainActor
final class CGWindowGeometryProvider: GeometryProvider {
    static func rawWindowCount(ownerPID: Int32) -> Int {
        windowRecords().filter { $0.ownerPID == ownerPID && $0.isOnScreen }.count
    }

    static func runningWindowDescriptors(ownerPID: Int32) -> [RunningWindowDescriptor] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }
        return info.compactMap { dictionary in
            guard (dictionary[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID,
                  let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary else { return nil }
            var rect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &rect) else { return nil }
            return RunningWindowDescriptor(
                name: dictionary[kCGWindowName as String] as? String ?? "",
                width: rect.width,
                height: rect.height
            )
        }
    }

    func snapshot() -> GeometrySnapshot {
        let displays = MacScreenProvider.displays()
        let records = Self.windowRecords()
        let accepted = WindowFilter.normalize(
            records: records,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            mainScreenMaxY: MacScreenProvider.mainScreenMaxY(),
            displayBounds: displays
        )
        let acceptedIDs = Set(accepted.map { UInt32($0.id.dropFirst("window-".count)) ?? 0 })
        let ownerPIDs = records.filter { acceptedIDs.contains($0.id) }.map(\.ownerPID)
        return GeometrySnapshot(
            displays: displays,
            obstacles: accepted,
            ownerPIDs: Array(Set(ownerPIDs)),
            capturedAt: Date()
        )
    }

    private static func windowRecords() -> [RawWindowRecord] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return info.compactMap { dictionary in
            guard let id = (dictionary[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (dictionary[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let layer = (dictionary[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary else { return nil }
            var cgRect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &cgRect),
                  let bounds = WorldRect(x: cgRect.origin.x, y: cgRect.origin.y, width: cgRect.width, height: cgRect.height) else { return nil }
            return RawWindowRecord(
                id: id,
                ownerPID: pid,
                layer: layer,
                alpha: (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                bounds: bounds,
                ownerName: dictionary[kCGWindowOwnerName as String] as? String ?? "",
                isOnScreen: (dictionary[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? true
            )
        }
    }
}
