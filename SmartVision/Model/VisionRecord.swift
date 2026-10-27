import UIKit

/// 识图记录（数据模型 M）
/// 持久化方案与课堂 InfoList 实验一致：NSObject + NSCoding + NSKeyedArchiver 归档
final class VisionRecord: NSObject, NSCoding {

    // MARK: 属性
    var id: String           // 唯一标识（也用作缩略图缓存键）
    var title: String        // 展示标题（中文优先）
    var english: String      // 模型输出的原始英文标签
    var confidence: Double   // Top-1 置信度 0~1
    var topFive: String      // Top-5 序列化串："英文|置信度;英文|置信度;…"（分隔符用分号，避免与标签内逗号冲突）
    var date: Date           // 识别时间
    var imagePath: String    // 照片在 Documents/images 下的文件名

    // MARK: 归档路径（课堂 Info.swift 的写法）
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                             in: .userDomainMask).first!
    static let imagesDirectory = documentsDirectory.appendingPathComponent("images", isDirectory: true)
    static let archiveURL = documentsDirectory.appendingPathComponent("visionRecords")

    // MARK: 键值结构（课堂 PropertyKey 的写法）
    struct PropertyKey {
        static let id = "id"
        static let title = "title"
        static let english = "english"
        static let confidence = "confidence"
        static let topFive = "topFive"
        static let date = "date"
        static let imagePath = "imagePath"
    }

    init(title: String, english: String, confidence: Double,
         topFive: String, imagePath: String, date: Date = Date()) {
        self.id = UUID().uuidString
        self.title = title
        self.english = english
        self.confidence = confidence
        self.topFive = topFive
        self.imagePath = imagePath
        self.date = date
        super.init()
    }

    // MARK: NSCoding
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: PropertyKey.id)
        coder.encode(title, forKey: PropertyKey.title)
        coder.encode(english, forKey: PropertyKey.english)
        coder.encode(confidence, forKey: PropertyKey.confidence)
        coder.encode(topFive, forKey: PropertyKey.topFive)
        coder.encode(date, forKey: PropertyKey.date)
        coder.encode(imagePath, forKey: PropertyKey.imagePath)
    }

    required convenience init?(coder: NSCoder) {
        guard let id = coder.decodeObject(forKey: PropertyKey.id) as? String,
              let title = coder.decodeObject(forKey: PropertyKey.title) as? String,
              let english = coder.decodeObject(forKey: PropertyKey.english) as? String,
              let imagePath = coder.decodeObject(forKey: PropertyKey.imagePath) as? String else {
            return nil
        }
        let confidence = coder.decodeDouble(forKey: PropertyKey.confidence)
        let topFive = coder.decodeObject(forKey: PropertyKey.topFive) as? String ?? ""
        let date = coder.decodeObject(forKey: PropertyKey.date) as? Date ?? Date()
        self.init(title: title, english: english, confidence: confidence,
                  topFive: topFive, imagePath: imagePath, date: date)
    }

    // MARK: Top-5 回放
    /// 把归档的 Top-5 序列化串还原成置信度图表数据
    func chartItems() -> [ConfidenceChartView.Item] {
        guard !topFive.isEmpty else {
            return [ConfidenceChartView.Item(name: title, confidence: confidence)]
        }
        return topFive.split(separator: ";").compactMap { segment -> ConfidenceChartView.Item? in
            let parts = segment.split(separator: "|")
            guard parts.count == 2, let value = Double(parts[1]) else { return nil }
            let englishLabel = String(parts[0])
            return ConfidenceChartView.Item(name: Labels.displayName(for: englishLabel),
                                            confidence: value)
        }
    }
}
