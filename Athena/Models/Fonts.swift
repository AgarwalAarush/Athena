//
//  Fonts.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import SwiftUI
import CoreText

extension Font {
    /// Main app font - Apercu Regular Pro
    static var apercu: Font {
        // Try to load the font, fallback to system font if not available
        if let fontName = Font.apercuFontName {
            return .custom(fontName, size: 14)
        }
        return .body
    }
    
    /// Apercu font with custom size
    static func apercu(size: CGFloat) -> Font {
        if let fontName = Font.apercuFontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size)
    }
    
    /// Get the registered font name
    private static var apercuFontName: String? {
        #if os(macOS)
        // On macOS, try PostScript name first (confirmed via otfinfo)
        let possibleNames = [
            "ApercuPro",  // PostScript name
            "ApercuPro-Regular",
            "Apercu-Regular-Pro",
            "Apercu Regular Pro",
            "Apercu",
            "apercu_regular_pro"
        ]
        
        for name in possibleNames {
            if NSFont(name: name, size: 12) != nil {
                return name
            }
        }
        
        // Try to load from bundle and get PostScript name
        if let fontURL = Bundle.main.url(forResource: "apercu_regular_pro", withExtension: "otf"),
           let fontData = try? Data(contentsOf: fontURL),
           let fontDataProvider = CGDataProvider(data: fontData as CFData),
           let font = CGFont(fontDataProvider),
           let postScriptName = font.postScriptName {
            return postScriptName as String
        }
        #else
        // iOS fallback
        let possibleNames = [
            "ApercuPro-Regular",
            "Apercu-Regular-Pro",
            "Apercu Regular Pro",
            "ApercuPro",
            "Apercu"
        ]
        
        for name in possibleNames {
            if UIFont(name: name, size: 12) != nil {
                return name
            }
        }
        #endif
        
        return nil
    }
}

#if os(macOS)
import AppKit
import CoreText

extension NSFont {
    /// Main app font - Apercu Regular Pro
    static var apercu: NSFont {
        if let fontName = NSFont.apercuFontName {
            return NSFont(name: fontName, size: 14) ?? .systemFont(ofSize: 14)
        }
        return .systemFont(ofSize: 14)
    }
    
    /// Apercu font with custom size
    static func apercu(size: CGFloat) -> NSFont {
        if let fontName = NSFont.apercuFontName {
            return NSFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        }
        return .systemFont(ofSize: size)
    }
    
    /// Get the registered font name
    private static var apercuFontName: String? {
        // PostScript name confirmed via otfinfo
        let possibleNames = [
            "ApercuPro",  // PostScript name (confirmed)
            "ApercuPro-Regular",
            "Apercu-Regular-Pro",
            "Apercu Regular Pro",
            "Apercu"
        ]
        
        for name in possibleNames {
            if NSFont(name: name, size: 12) != nil {
                return name
            }
        }
        
        // Try to load from bundle and get PostScript name as fallback
        if let fontURL = Bundle.main.url(forResource: "apercu_regular_pro", withExtension: "otf"),
           let fontData = try? Data(contentsOf: fontURL),
           let fontDataProvider = CGDataProvider(data: fontData as CFData),
           let font = CGFont(fontDataProvider),
           let postScriptName = font.postScriptName {
            return postScriptName as String
        }
        
        return nil
    }
}
#endif

