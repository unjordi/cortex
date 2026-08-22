using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace Cortex;

/// <summary>
/// Draws the tray indicator. The old two-mini-bar design ("5h" over "7d") was
/// illegible in a 16-24px square and read as "not even updating", so it now shows
/// a single glanceable signal:
///
///   • data available  → the <b>5h utilization %</b> as one big auto-scaled number
///     that fills the square, in claude-orange (<see cref="Fmt.Accent"/>), turning
///     red (<see cref="Fmt.Danger"/>) past 90% via <see cref="Fmt.PctColor"/>.
///   • no data / error  → the brand icon (<see cref="BrandIcon.Small"/>), the
///     "precious" fallback; last resort is a small danger dot so the tray never
///     goes blank.
///
/// The exact figures, the 7d window, labels and ⟳reset live in the tooltip and the
/// popup — the tray is a single number you can read at a glance. Redrawn on the
/// 10s tray timer (Program.RedrawIcon); the caller owns the returned HICON and must
/// call <see cref="Release"/> after swapping it out or the GDI handle leaks.
/// </summary>
public static class TrayIconRenderer
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    public readonly record struct Row(double? Pct);

    /// <summary>Build the tray icon at the given square size (px). <paramref name="week"/> is
    /// unused now (the 7d figure moved to the tooltip/popup); kept so callers don't change.
    /// Caller must call <see cref="Release"/> on the returned handle once the icon is swapped
    /// out, or the GDI icon handle leaks.</summary>
    public static (Icon icon, IntPtr handle) Render(Row five, Row week, bool hasError, int size)
    {
        _ = week;   // 7d ya no se dibuja en el cuadrito; vive en tooltip/popup.
        // Con dato de 5h → % grande; sin dato (o error) → ícono de marca.
        return five.Pct is double pct ? RenderPercent(pct, size) : RenderBrand(size);
    }

    public static void Release(IntPtr handle)
    {
        if (handle != IntPtr.Zero) DestroyIcon(handle);
    }

    /// El % de 5h como texto grande, centrado y auto-escalado para llenar el cuadrado.
    /// "NN%" mientras quepa; para 3 dígitos (100) se cae a solo el número, que lee mejor.
    /// Color naranja-claude, o rojo &gt;90% (misma señal de throttle que las barras/popup).
    private static (Icon, IntPtr) RenderPercent(double pct, int size)
    {
        int p = (int)Math.Round(Math.Clamp(pct, 0, 999));
        string text = p >= 100 ? p.ToString() : $"{p}%";

        using var bmp = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            // AntiAliasGridFit (no ClearType): el fondo es TRANSPARENTE y ClearType asume un
            // fondo opaco → dejaría flecos de color sobre la barra de tareas. AntiAlias compone
            // limpio sobre cualquier color de taskbar (claro u oscuro).
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

            using var sf = new StringFormat(StringFormat.GenericTypographic)
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center,
                FormatFlags = StringFormatFlags.NoWrap | StringFormatFlags.NoClip,
            };
            using var font = FitFont(g, text, size);
            using var brush = new SolidBrush(Fmt.PctColor(pct));
            g.DrawString(text, font, brush, new RectangleF(0, 0, size, size), sf);
        }

        IntPtr h = bmp.GetHicon();   // HICON independiente: sobrevive al Dispose del bmp.
        return (Icon.FromHandle(h), h);
    }

    /// El ícono de marca (cortex) escalado al size — el fallback "precioso" cuando no hay
    /// dato de 5h. Si el brand no decodifica, un punto de peligro para no devolver un icono vacío.
    private static (Icon, IntPtr) RenderBrand(int size)
    {
        using var bmp = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            var brand = BrandIcon.Small();
            if (brand != null)
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(brand, new Rectangle(0, 0, size, size));
            }
            else
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                float d = MathF.Max(4f, size * 0.5f);
                using var eb = new SolidBrush(Fmt.Hex(Fmt.Danger));
                g.FillEllipse(eb, (size - d) / 2f, (size - d) / 2f, d, d);
            }
        }

        IntPtr h = bmp.GetHicon();
        return (Icon.FromHandle(h), h);
    }

    /// Fuente Bold que MAXIMIZA el tamaño sin que el texto se salga del cuadrado. Baja desde ~size
    /// midiendo el string real hasta que ancho y alto caben con un pelín de margen.
    private static Font FitFont(Graphics g, string text, int size)
    {
        float pad = MathF.Max(1f, size * 0.08f);
        var tf = StringFormat.GenericTypographic;
        for (float fs = size; fs >= 5f; fs -= 0.5f)
        {
            var f = new Font("Segoe UI", fs, FontStyle.Bold, GraphicsUnit.Pixel);
            var m = g.MeasureString(text, f, PointF.Empty, tf);
            if (m.Width <= size - pad && m.Height <= size - pad) return f;
            f.Dispose();
        }
        return new Font("Segoe UI", 5f, FontStyle.Bold, GraphicsUnit.Pixel);
    }
}
