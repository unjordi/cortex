import AppKit
let five = PillImage.RowData(label: "5h", pct: 50, reset: nil)
let week = PillImage.RowData(label: "7d", pct: 12, reset: nil)
struct St { let name: String; let update: Bool; let heal: Bool }
let states = [ St(name:"update — hay versión nueva", update:true, heal:false),
               St(name:"heal — falta curar el cerebro", update:false, heal:true),
               St(name:"ambos", update:true, heal:true) ]
let themes: [(String, NSAppearance?)] = [("barra oscura", NSAppearance(named:.darkAqua)), ("barra clara", NSAppearance(named:.aqua))]
let scales: [CGFloat] = [1, 4]
let rowH: CGFloat = 120, labelW: CGFloat = 230, cellW: CGFloat = 470, pad: CGFloat = 16
let sheetW = labelW + cellW*2 + pad*3
let sheetH = rowH*CGFloat(states.count) + pad*2 + 34
let sheet = NSImage(size: NSSize(width: sheetW, height: sheetH))
sheet.lockFocus()
NSColor(hex:"#f4f4f4").setFill(); NSRect(x:0,y:0,width:sheetW,height:sheetH).fill()
("Indicador de barra de menú — 5h = 50% · 7d = 12% (real 1× y ampliado 4×)" as NSString)
    .draw(at: NSPoint(x: pad, y: sheetH-26), withAttributes: [.font: NSFont.boldSystemFont(ofSize:13), .foregroundColor: NSColor.black])
for (ri, st) in states.enumerated() {
    let y0 = sheetH - 34 - rowH*CGFloat(ri+1)
    (st.name as NSString).draw(at: NSPoint(x: pad, y: y0 + rowH/2 - 8),
        withAttributes: [.font: NSFont.systemFont(ofSize:12, weight:.medium), .foregroundColor: NSColor.black])
    for (ti, th) in themes.enumerated() {
        let cx = labelW + pad*CGFloat(ti+1) + cellW*CGFloat(ti)
        (ti==0 ? NSColor(hex:"#2a2a2a") : NSColor(hex:"#e9e9e9")).setFill()
        NSRect(x: cx, y: y0+8, width: cellW, height: rowH-16).fill()
        (th.0 as NSString).draw(at: NSPoint(x: cx+8, y: y0+rowH-26),
            withAttributes: [.font: NSFont.systemFont(ofSize:9), .foregroundColor: ti==0 ? NSColor.white : NSColor.darkGray])
        let img = PillImage.render(five: five, week: week, hasError: false, update: st.update, heal: st.heal, appearance: th.1)
        var px = cx + 16; let cy = y0 + rowH/2 - 8
        for s in scales {
            let w = img.size.width*s, h = img.size.height*s
            img.draw(in: NSRect(x: px, y: cy - h/2, width: w, height: h), from: .zero,
                     operation: .sourceOver, fraction: 1, respectFlipped: true,
                     hints: [.interpolation: NSImageInterpolation.none.rawValue])
            ("\(Int(s))×" as NSString).draw(at: NSPoint(x: px, y: cy - h/2 - 15),
                withAttributes: [.font: NSFont.systemFont(ofSize:8), .foregroundColor: ti==0 ? NSColor.lightGray : NSColor.gray])
            px += w + 34
        }
    }
}
sheet.unlockFocus()
if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[1])); print("escrito: \(CommandLine.arguments[1])")
}
