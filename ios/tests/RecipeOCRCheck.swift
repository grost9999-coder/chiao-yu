import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

@main
struct RecipeOCRCheck {
    static func image(lines: [String]) -> Data {
        let context = CGContext(data: nil, width: 1000, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 400))
        for (index, text) in lines.enumerated() {
            context.textPosition = CGPoint(x: 50, y: 290 - 100 * index)
            let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("PingFangTC-Regular" as CFString, 48, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs) as CFAttributedString), context)
        }
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(dest))
        return data as Data
    }
    static func main() throws {
        let text = try LedgerRecipeOCR.text(in: image(lines: ["SOY SAUCE 100 g", "SUGAR 50 g", "醬油 200公克"]))
        precondition(text.uppercased().contains("SOY SAUCE"), "Native Vision missed ingredient: \(text)")
        precondition(text.contains("醬油"), "Native Vision missed Chinese ingredient: \(text)")
        precondition(text.contains("100") && text.contains("50"), "Native Vision missed quantities")
        let blank = try LedgerRecipeOCR.text(in: image(lines: []))
        precondition(blank.isEmpty, "Blank photo must not invent a recipe")
        do { _ = try LedgerRecipeOCR.text(in: Data("not an image".utf8)); fatalError("Invalid image accepted") } catch { }
        print("PASS: actual native Vision recognizes ingredient names and quantities, blank/invalid images")
    }
}
