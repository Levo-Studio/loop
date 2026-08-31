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

    /// `actool` writes one of these per idiom, and the target builds for both
    /// (`TARGETED_DEVICE_FAMILY = "1,2"`). `Bundle.main` resolves the suffix for
    /// the device the tests run on and drops the other idiom's key, so asking it
    /// for `CFBundleIcons~ipad` on an iPhone finds nothing even when the iPad
    /// icon shipped correctly — the guard would fail on a sound build. The raw
    /// plist is read instead, which is the same on either device.
    private static let iconKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]

    /// The Info.plist as it sits on disk, where both idioms' keys are still
    /// present. `Bundle.main.infoDictionary` is the wrong source for this test:
    /// it has already collapsed the `~ipad` variants down to the idiom of the
    /// running device and discarded the other one. The discarded key is exactly
    /// the one the test has to check, so the file is parsed directly instead.
    private func rawInfoPlist() throws -> [String: Any] {
        let url = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    private func primaryIcon(in plist: [String: Any], forKey key: String) throws -> [String: Any] {
        let icons = try #require(plist[key] as? [String: Any], "\(key) is missing from the Info.plist")
        return try #require(icons["CFBundlePrimaryIcon"] as? [String: Any], "\(key) has no primary icon")
    }

    /// An Icon Composer icon is named under `CFBundleIcons`, not at the top
    /// level of the Info.plist. A missing key means
    /// `ASSETCATALOG_COMPILER_APPICON_NAME` no longer names an icon the asset
    /// catalog knows about.
    @Test("The primary icon is named for both idioms")
    func primaryIconIsNamed() throws {
        let plist = try rawInfoPlist()
        for key in Self.iconKeys {
            let primary = try primaryIcon(in: plist, forKey: key)
            #expect(primary["CFBundleIconName"] as? String == Self.iconName, "wrong icon name under \(key)")
        }
    }

    /// Naming it is not shipping it. Alongside the compiled `Assets.car`,
    /// `actool` writes flattened PNGs into the bundle root and lists them in
    /// `CFBundleIconFiles` — they exist only if it genuinely rendered the icon,
    /// which makes them the cheapest proof that it did.
    ///
    /// The stack itself is deliberately never loaded through `UIImage(named:)`.
    /// That call has two outcomes on a correctly built app, and which one you
    /// get is decided by the build rather than by the source: `actool`'s
    /// icon-stack output is not deterministic, so `Assets.car` differs between
    /// builds of an identical tree. Where a partially decodable rendition lands
    /// in it, UIKit raises `NSInternalInconsistencyException` ("Need an
    /// imageRef") and takes the whole test process down; where none does, the
    /// call returns nil. Both were reproduced on this branch. Either outcome
    /// makes it useless as a guard — one kills the run, the other is red on a
    /// perfectly good icon — so the rendered files are checked instead.
    @Test("The rendered icon files are in the bundle and carry pixels")
    func iconFilesAreRendered() throws {
        let plist = try rawInfoPlist()
        let root = Bundle.main.bundleURL
        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)

        for key in Self.iconKeys {
            let primary = try primaryIcon(in: plist, forKey: key)
            let files = try #require(primary["CFBundleIconFiles"] as? [String], "\(key) lists no icon files")
            #expect(files.isEmpty == false, "\(key) lists no icon files")

            for file in files {
                #expect(file.hasPrefix(Self.iconName), "\(file) does not belong to \(Self.iconName)")

                // The entries name the icon without its scale or idiom suffix,
                // so the rendition is matched on the stem rather than looked up
                // by an exact filename that only holds for one of them.
                let renditions = contents.filter { $0.hasPrefix(file + "@") && $0.hasSuffix(".png") }
                #expect(renditions.isEmpty == false, "no rendered PNG for \(file) (\(key))")

                for rendition in renditions {
                    let image = try #require(
                        UIImage(contentsOfFile: root.appendingPathComponent(rendition).path),
                        "\(rendition) is not a readable image"
                    )
                    #expect(image.size.width >= 60, "\(rendition) is too small to be the real artwork")
                    #expect(image.size.height >= 60, "\(rendition) is too small to be the real artwork")
                }
            }
        }
    }
}
