import UIKit

enum DeviceIdentifier {
    @MainActor
    static var current: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "ios-\(UUID().uuidString)"
    }
}
