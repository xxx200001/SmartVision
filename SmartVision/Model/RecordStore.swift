import UIKit

/// 识图记录仓库：统一管理归档读写与图片文件的增删（单例共享）
final class RecordStore {

    static let shared = RecordStore()

    /// 全部记录（最新在前）
    private(set) var records: [VisionRecord] = []

    /// 从「识图历史」点选某条记录后，回到识别页回放时传递数据用
    var pendingShow: VisionRecord?

    private init() {
        // 首次运行时确保图片目录存在
        try? FileManager.default.createDirectory(at: VisionRecord.imagesDirectory,
                                                 withIntermediateDirectories: true)
        records = load() ?? []
    }

    // MARK: 归档读写（课堂 NSKeyedArchiver / NSKeyedUnarchiver 的写法）
    private func load() -> [VisionRecord]? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: VisionRecord.archiveURL.path) as? [VisionRecord]
    }

    private func save() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(records, toFile: VisionRecord.archiveURL.path)
        if !isSuccessfulSave {
            print("Failed to save vision records...")
        }
    }

    // MARK: 增
    func add(_ record: VisionRecord) {
        records.insert(record, at: 0)
        save()
    }

    // MARK: 删（连同照片文件一起删除）
    func delete(at index: Int) {
        guard index >= 0 && index < records.count else { return }
        let record = records.remove(at: index)
        let url = VisionRecord.imagesDirectory.appendingPathComponent(record.imagePath)
        try? FileManager.default.removeItem(at: url)
        save()
    }

    // MARK: 照片存取
    /// 把照片写入 Documents/images，返回生成的文件名
    @discardableResult
    func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let url = VisionRecord.imagesDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url)
            return fileName
        } catch {
            print("Failed to write image: \(error)")
            return nil
        }
    }

    /// 按文件名读取照片
    func loadImage(named name: String) -> UIImage? {
        let url = VisionRecord.imagesDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
