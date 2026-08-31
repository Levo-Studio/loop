import Foundation
import Testing
import UIKit

/// The app icon is wired up entirely in `project.pbxproj` — a build setting and
/// a Resources entry, neither of which any Swift file mentions. When that wiring
/// breaks, the build stays green and ships a white placeholder instead. These
/// checks are the only thing standing between that and a release.
@Suite("App icon")
struct LoopAppIconTests {

    /// The name `actool` is told to compile, which is also the name of the Icon
    /// Composer document at the repository root. The two have to agree, so the
    /// document can never be renamed on its own.
    private static let iconName = "loop-icon"

    /// An Icon Composer icon is named under `CFBundleIcons`, not at the top
    /// level of the Info.plist. A missing key means
    /// `ASSETCATALOG_COMPILER_APPICON_NAME` no longer names an icon the asset
    /// catalog knows about.
    @Test("The primary icon is named in the Info.plist")
    func primaryIconIsNamed() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == Self.iconName)
    }

    /// Naming it is not shipping it. Alongside the compiled `Assets.car`,
    /// `actool` writes flattened PNGs into the bundle root and lists them in
    /// `CFBundleIconFiles` — they exist only if it genuinely rendered the icon,
    /// which makes them the cheapest proof that it did.
    ///
    /// The stack itself is deliberately not loaded through `UIImage(named:)`:
    /// an icon stack is not an image asset and asking for it as one raises.
    @Test("The rendered icon files are in the bundle and carry pixels")
    func iconFilesAreRendered() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        #expect(files.isEmpty == false)

        for file in files {
            #expect(file.hasPrefix(Self.iconName), "\(file) does not belong to \(Self.iconName)")

            // The bundle holds the @2x variant; `path(forResource:)` does not
            // resolve the scale suffix on its own for a plain resource lookup.
            let path = try #require(
                Bundle.main.path(forResource: "\(file)@2x", ofType: "png"),
                "no rendered PNG for \(file)"
            )
            let image = try #require(UIImage(contentsOfFile: path), "\(file)@2x.png is not a readable image")
            #expect(image.size.width >= 60)
            #expect(image.size.height >= 60)
        }
    }
}
