import SwiftUI

/// Top-down head (nose at the top). Each sensor's circle size shows how strongly it
/// contributed; teal pushes toward RIGHT hand, amber toward LEFT hand.
struct HeadMapView: View {
    let channelNames: [String]
    let contributions: [Double]

    /// Approximate 10-20 positions. x: −1 left … +1 right, y: −1 back … +1 front.
    static let positions: [String: CGPoint] = [
        "FC3": CGPoint(x: -0.5, y: 0.3), "FCz": CGPoint(x: 0, y: 0.3), "FC4": CGPoint(x: 0.5, y: 0.3),
        "C5": CGPoint(x: -0.75, y: 0), "C3": CGPoint(x: -0.5, y: 0), "C1": CGPoint(x: -0.25, y: 0),
        "Cz": CGPoint(x: 0, y: 0),
        "C2": CGPoint(x: 0.25, y: 0), "C4": CGPoint(x: 0.5, y: 0), "C6": CGPoint(x: 0.75, y: 0),
        "CP3": CGPoint(x: -0.5, y: -0.3), "CPz": CGPoint(x: 0, y: -0.3), "CP4": CGPoint(x: 0.5, y: -0.3),
    ]

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let r = side * 0.36
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + side * 0.03)
            let outline = GraphicsContext.Shading.color(Theme.textSecondary.opacity(0.7))

            // Head, nose, ears
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: outline, lineWidth: 2)
            var nose = Path()
            nose.move(to: CGPoint(x: c.x - r * 0.13, y: c.y - r * 0.99))
            nose.addLine(to: CGPoint(x: c.x, y: c.y - r * 1.14))
            nose.addLine(to: CGPoint(x: c.x + r * 0.13, y: c.y - r * 0.99))
            context.stroke(nose, with: outline, lineWidth: 2)
            for sign in [-1.0, 1.0] {
                let ear = CGRect(x: c.x + sign * r - r * 0.07 + sign * r * 0.05, y: c.y - r * 0.17,
                                 width: r * 0.14, height: r * 0.34)
                context.stroke(Path(ellipseIn: ear), with: outline, lineWidth: 2)
            }

            context.draw(Text("L").font(.headline).foregroundColor(Theme.textSecondary),
                         at: CGPoint(x: c.x - r * 1.28, y: c.y))
            context.draw(Text("R").font(.headline).foregroundColor(Theme.textSecondary),
                         at: CGPoint(x: c.x + r * 1.28, y: c.y))

            // Sensors
            let maxAbs = max(contributions.map(abs).max() ?? 0, 1e-9)
            for (index, name) in channelNames.enumerated() {
                guard let pos = Self.positions[name], index < contributions.count else { continue }
                let value = contributions[index]
                let strength = abs(value) / maxAbs
                let diameter = r * (0.08 + 0.16 * strength)
                let point = CGPoint(x: c.x + pos.x * r, y: c.y - pos.y * r)
                let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                  width: diameter, height: diameter)
                let color = value >= 0 ? Theme.teal : Theme.amber

                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 + 0.65 * strength)))
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.5)
                context.draw(
                    Text(name).font(.caption2.weight(.bold)).foregroundColor(.white),
                    at: CGPoint(x: point.x, y: point.y + diameter / 2 + 8)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Head map of sensor contributions")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let ranked = zip(channelNames, contributions)
            .sorted { abs($0.1) > abs($1.1) }
            .prefix(3)
            .map { "\($0.0) toward \($0.1 >= 0 ? "right" : "left")" }
        return "Strongest: " + ranked.joined(separator: ", ")
    }
}

#Preview {
    HeadMapView(
        channelNames: ["FC3", "FCz", "FC4", "C5", "C3", "C1", "Cz", "C2", "C4", "C6", "CP3", "CPz", "CP4"],
        contributions: [0.2, -0.1, 0.4, -0.3, -0.8, 0.1, 0.05, 0.3, 1.0, 0.2, -0.4, 0.0, 0.5]
    )
    .padding()
    .background(Theme.navy)
}
