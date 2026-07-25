import AppKit
// Stubs MÍNIMOS para renderizar PillImage.swift aislado (sin arrastrar todo el módulo).
// Espejan helpers reales de QuotaModel.swift/Format — si esos cambian de convención, actualízalos.
extension NSColor {
    convenience init(hex: String) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255,
                  blue: CGFloat(v&0xff)/255, alpha: 1)
    }
}
enum RelativeTime { static func compactReset(_ s: String) -> String { "" } }
func pctHex(_ p: Double?) -> String { p == nil ? "#777777" : (p! > 90 ? "#dc3545" : "#e8884a") }
