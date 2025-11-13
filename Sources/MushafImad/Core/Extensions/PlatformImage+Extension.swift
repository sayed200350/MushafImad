//
//  PlatformImage+Extension.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

#if canImport(UIKit)
import UIKit

// UIImage is safe to send across concurrency boundaries as it's immutable
extension UIImage: @unchecked Sendable {}

#elseif canImport(AppKit)
import AppKit
public typealias UIImage = NSImage

// NSImage is safe to send across concurrency boundaries as it's immutable
extension NSImage: @unchecked Sendable {}

public extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif

