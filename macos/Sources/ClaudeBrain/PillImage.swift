import AppKit

/// Renders the two-row menu-bar indicator (AppKit analogue of the plasmoid's
/// compactRepresentation): a "5h" row and a "7d" row, each = label + mini bar +
/// "N%" + "⟳{compactReset}". Height ≈ 22px (the usable menu-bar height); its
/// width measures to the actual rendered content so the status item never
/// collapses. isTemplate = false because it carries its own accent colors.
enum PillImage {
    struct RowData {
        let label: String
        let pct: Double?
        let reset: String?
    }

    private static let height: CGFloat = 22
    private static let barW: CGFloat = 30
    private static let barH: CGFloat = 4
    private static let gap: CGFloat = 3
    private static let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
    private static let pctFont   = NSFont.systemFont(ofSize: 8, weight: .bold)
    private static let resetFont = NSFont.systemFont(ofSize: 7, weight: .regular)
    // Acentos de los avisos del cerebro (hex fijos: llevan su propio color, isTemplate=false).
    private static let updateHex = "#e8884a"   // ⬆ naranja: update disponible
    private static let healHex   = "#dc3545"   // ✚ roja:    falta curar el cerebro

    static func render(five: RowData, week: RowData, hasError: Bool,
                       update: Bool = false, heal: Bool = false,
                       appearance: NSAppearance?) -> NSImage {
        let rows = [five, week]

        // Column X where the label ends / the bar starts (aligned across rows).
        let labelW = ceil(rows.map { width($0.label, labelFont) }.max() ?? 8)
        let barX = labelW + gap
        let pctX = barX + barW + gap

        // Per-row trailing content (pct + optional reset) → total width.
        var maxWidth: CGFloat = pctX
        for r in rows {
            let pctW = ceil(width(pctText(r, hasError: hasError), pctFont))
            var w = pctX + pctW
            let rt = resetText(r)
            if !rt.isEmpty { w += gap + ceil(width(rt, resetFont)) }
            maxWidth = max(maxWidth, w)
        }
        // Reserva a la derecha una COLUMNA de avisos del cerebro, dibujados como glifos
        // VECTORIALES legibles (no un puntito críptico): ⬆ naranja = update disponible,
        // ✚ roja = falta curar el cerebro. Si ambos, apilados (cruz arriba, flecha abajo).
        let anyAviso = update || heal
        let bothAvisos = update && heal
        // Badge (fondo redondeado tenue) + glifo. El caso apilado usa un badge menor para que
        // los dos quepan en los 22px de alto sin encimarse.
        let badgeSingle: CGFloat = 15, glyphSingle: CGFloat = 11
        let badgeStack:  CGFloat = 11, glyphStack:  CGFloat = 8
        let reserveW = bothAvisos ? badgeStack : badgeSingle
        let totalW = ceil(maxWidth) + 2 + (anyAviso ? reserveW + 4 : 0)

        let image = NSImage(size: NSSize(width: totalW, height: height))
        let draw = {
            image.lockFocus()
            // Two rows: top row center y=15, bottom row center y=6 (2px inner margins).
            drawRow(rows[0], hasError: hasError, centerY: 15, barX: barX, pctX: pctX)
            drawRow(rows[1], hasError: hasError, centerY: 6,  barX: barX, pctX: pctX)
            // Avisos del cerebro a la derecha (glifos vectoriales legibles).
            if anyAviso {
                if bothAvisos {
                    // Apilados: cruz roja (heal) arriba, flecha naranja (update) abajo.
                    let cx = totalW - 2 - badgeStack / 2
                    drawCross(cx: cx,   cy: 16.5, badge: badgeStack, glyph: glyphStack, hex: healHex)
                    drawUpArrow(cx: cx, cy: 5.5,  badge: badgeStack, glyph: glyphStack, hex: updateHex)
                } else {
                    let cx = totalW - 2 - badgeSingle / 2
                    let cy = height / 2
                    if heal {
                        drawCross(cx: cx, cy: cy, badge: badgeSingle, glyph: glyphSingle, hex: healHex)
                    } else {
                        drawUpArrow(cx: cx, cy: cy, badge: badgeSingle, glyph: glyphSingle, hex: updateHex)
                    }
                }
            }
            image.unlockFocus()
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(draw)
        } else {
            draw()
        }
        image.isTemplate = false
        return image
    }

    // MARK: - drawing

    private static func drawRow(_ r: RowData, hasError: Bool, centerY: CGFloat,
                                barX: CGFloat, pctX: CGFloat) {
        let accent = NSColor(hex: pctHex(r.pct))

        // label
        drawText(r.label, font: labelFont,
                 color: NSColor.labelColor.withAlphaComponent(0.7),
                 x: 0, centerY: centerY)

        // mini bar (solo si hay dato)
        if let p = r.pct {
            let barY = centerY - barH / 2
            let bg = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barW, height: barH),
                                  xRadius: barH / 2, yRadius: barH / 2)
            NSColor.labelColor.withAlphaComponent(0.15).setFill()
            bg.fill()
            let fillW = barW * CGFloat(max(0, min(1, p / 100)))
            if fillW > 0 {
                let fg = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: fillW, height: barH),
                                      xRadius: barH / 2, yRadius: barH / 2)
                accent.setFill()
                fg.fill()
            }
        }

        // "N%" (o "!"/"…")
        let pt = pctText(r, hasError: hasError)
        let pctW = drawText(pt, font: pctFont, color: accent, x: pctX, centerY: centerY)

        // "⟳{compactReset}"
        let rt = resetText(r)
        if !rt.isEmpty {
            drawText(rt, font: resetFont,
                     color: NSColor.labelColor.withAlphaComponent(0.55),
                     x: pctX + pctW + gap, centerY: centerY)
        }
    }

    private static func pctText(_ r: RowData, hasError: Bool) -> String {
        if let p = r.pct { return "\(Int(p.rounded()))%" }
        return hasError ? "!" : "…"
    }
    private static func resetText(_ r: RowData) -> String {
        guard let reset = r.reset, !reset.isEmpty, r.pct != nil else { return "" }
        let c = RelativeTime.compactReset(reset)
        return c.isEmpty ? "" : "⟳\(c)"
    }

    @discardableResult
    private static func drawText(_ s: String, font: NSFont, color: NSColor,
                                 x: CGFloat, centerY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: x, y: centerY - sz.height / 2), withAttributes: attrs)
        return sz.width
    }

    private static func width(_ s: String, _ font: NSFont) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: font]).width
    }

    /// Badge redondeado tenue del color del aviso (mejora el contraste del glifo).
    private static func drawBadge(cx: CGFloat, cy: CGFloat, size: CGFloat, hex: String) {
        let r = NSRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
        NSColor(hex: hex).withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: r, xRadius: size * 0.3, yRadius: size * 0.3).fill()
    }

    /// Flecha "hacia arriba" (aviso: update disponible) — glifo vectorial relleno (cabeza + astil).
    private static func drawUpArrow(cx: CGFloat, cy: CGFloat, badge: CGFloat, glyph s: CGFloat, hex: String) {
        drawBadge(cx: cx, cy: cy, size: badge, hex: hex)
        let top = cy + s / 2, bottom = cy - s / 2
        let headBaseY = top - s * 0.52   // fin de la cabeza / inicio del astil
        let hw = s * 0.50                // media anchura de la cabeza (punta ancha)
        let sw = s * 0.16                // media anchura del astil (angosto)
        let p = NSBezierPath()
        p.move(to: NSPoint(x: cx,      y: top))
        p.line(to: NSPoint(x: cx + hw, y: headBaseY))
        p.line(to: NSPoint(x: cx + sw, y: headBaseY))
        p.line(to: NSPoint(x: cx + sw, y: bottom))
        p.line(to: NSPoint(x: cx - sw, y: bottom))
        p.line(to: NSPoint(x: cx - sw, y: headBaseY))
        p.line(to: NSPoint(x: cx - hw, y: headBaseY))
        p.close()
        NSColor(hex: hex).setFill()
        p.fill()
    }

    /// Cruz / símbolo médico "✚" (aviso: falta curar el cerebro) — dos barras redondeadas gruesas.
    private static func drawCross(cx: CGFloat, cy: CGFloat, badge: CGFloat, glyph s: CGFloat, hex: String) {
        drawBadge(cx: cx, cy: cy, size: badge, hex: hex)
        let t = s * 0.36   // grosor de cada barra
        let r = t * 0.35   // esquinas suaves
        NSColor(hex: hex).setFill()
        NSBezierPath(roundedRect: NSRect(x: cx - s / 2, y: cy - t / 2, width: s, height: t),
                     xRadius: r, yRadius: r).fill()
        NSBezierPath(roundedRect: NSRect(x: cx - t / 2, y: cy - s / 2, width: t, height: s),
                     xRadius: r, yRadius: r).fill()
    }
}
