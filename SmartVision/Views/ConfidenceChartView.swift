import UIKit

/// 自定义视图（View 层）：用 CoreGraphics / UIBezierPath 绘制 Top-5 置信度条形图
/// 对应课堂「视图 II」：UIView 子类 + draw(_:) + setNeedsDisplay() 的综合运用，
/// 同时自适应深色/浅色模式。
final class ConfidenceChartView: UIView {

    // MARK: 数据
    struct Item {
        let name: String
        let confidence: Double   // 0 ~ 1
    }

    var title: String = "识别结果 Top-5" {
        didSet { setNeedsDisplay() }
    }

    var items: [Item] = [] {
        didSet { setNeedsDisplay() }   // 永不手动调 draw(_:)，请求系统重绘
    }

    // MARK: 初始化（课堂：UIView 的两个初始化器都要处理，公共逻辑抽成 setup()）
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw   // 尺寸变化时触发重绘
    }

    // MARK: 绘制
    override func draw(_ rect: CGRect) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let titleColor = UIColor.label
        let trackColor = (isDark ? UIColor.white : UIColor.black).withAlphaComponent(0.08)

        let margin = CGFloat(4)
        let titleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let labelFont = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        let valueFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        // 空状态提示
        if items.isEmpty {
            let hint = "尚未识别\n点击左上角「拍照」或「相册」选择一张照片"
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineSpacing = 5
            hint.draw(in: rect.insetBy(dx: margin, dy: margin),
                      withAttributes: [.font: UIFont.systemFont(ofSize: 13),
                                       .foregroundColor: UIColor.secondaryLabel,
                                       .paragraphStyle: style])
            return
        }

        // 标题
        (title as NSString).draw(at: CGPoint(x: rect.minX + margin, y: rect.minY + 2),
                                 withAttributes: [.font: titleFont, .foregroundColor: titleColor])

        // 行高：剩余空间均分给 N 行，并保证最小高度
        let rowHeight = max((rect.height - 30) / CGFloat(items.count), 20)
        let nameLabelWidth = rect.width * 0.60
        let barHeight = CGFloat(5)
        let barInset = CGFloat(6)

        for (index, item) in items.enumerated() {
            let y = rect.minY + 26 + CGFloat(index) * rowHeight
            let textColor = index == 0 ? titleColor : UIColor.secondaryLabel

            // 类别名
            (item.name as NSString).draw(
                in: CGRect(x: rect.minX + margin, y: y + 2,
                           width: nameLabelWidth - margin, height: rowHeight - barInset),
                withAttributes: [.font: labelFont, .foregroundColor: textColor])

            // 百分比（右对齐）
            let percent = String(format: "%.1f%%", item.confidence * 100) as NSString
            let percentSize = percent.size(withAttributes: [.font: valueFont])
            percent.draw(at: CGPoint(x: rect.maxX - margin - percentSize.width, y: y + 2),
                         withAttributes: [.font: valueFont, .foregroundColor: textColor])

            // 底轨（圆角矩形：UIBezierPath(roundedRect:cornerRadius:)，课堂「视图 II」）
            let barRect = CGRect(x: rect.minX + margin, y: y + rowHeight - barInset,
                                 width: rect.width - margin * 2, height: barHeight)
            let track = UIBezierPath(roundedRect: barRect, cornerRadius: barHeight / 2)
            trackColor.setFill()
            track.fill()

            // 置信度条：宽度 = 轨道宽 × 置信度，颜色随排名由深蓝渐变为青蓝
            let clamped = CGFloat(min(max(item.confidence, 0), 1))
            let fillRect = CGRect(x: barRect.minX, y: barRect.minY,
                                  width: barRect.width * clamped, height: barRect.height)
            let fill = UIBezierPath(roundedRect: fillRect, cornerRadius: barHeight / 2)
            let hue = CGFloat(0.58 - 0.05 * Double(index))
            UIColor(hue: hue, saturation: 0.62, brightness: 0.95, alpha: 1).setFill()
            fill.fill()
        }
    }

    // 深浅色切换时请求重绘
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }
}
