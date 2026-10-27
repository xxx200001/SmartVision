import UIKit

/// 识图历史（UITableViewController）
/// 对应课堂 InfoList 实验：动态表视图 + editButtonItem 编辑模式 + commit 删除 + 数据持久化。
final class HistoryTableViewController: UITableViewController {

    private let cellIdentifier = "VisionRecordCell"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    /// 缩略图内存缓存（key = record.id）
    private var thumbnailCache: [String: UIImage] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "识图历史"
        // 课堂 InfoList Step 7：editButtonItem 进入编辑模式（删除）
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self,
                                                            action: #selector(doneTapped))
        tableView.rowHeight = 66
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    // MARK: - Table view data source（课堂 InfoList 的三个必须实现的方法）

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return RecordStore.shared.records.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = RecordStore.shared.records[indexPath.row]

        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil {
            // 课堂 SimpleTable 写法：subtitle 样式 + 复用
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        }
        cell?.imageView?.image = thumbnail(for: record)
        cell?.imageView?.layer.cornerRadius = 6
        cell?.imageView?.clipsToBounds = true
        cell?.textLabel?.text = record.title
        cell?.textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        let percent = String(format: "%.1f%%", record.confidence * 100)
        cell?.detailTextLabel?.text = "\(percent) · \(dateFormatter.string(from: record.date))"
        cell?.detailTextLabel?.textColor = .secondaryLabel
        cell?.accessoryType = .disclosureIndicator
        return cell!
    }

    // MARK: 删除（课堂 InfoList Step 8：编辑模式红减号与左滑均触发）
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            RecordStore.shared.delete(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // MARK: 点击记录 → 返回识别页回放
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        RecordStore.shared.pendingShow = RecordStore.shared.records[indexPath.row]
        dismiss(animated: true)
    }

    // MARK: 缩略图（降采样 + 缓存，保证列表滚动流畅）
    private func thumbnail(for record: VisionRecord) -> UIImage? {
        if let cached = thumbnailCache[record.id] { return cached }
        guard let image = RecordStore.shared.loadImage(named: record.imagePath) else { return nil }

        let side = CGFloat(44)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                            format: format).image { _ in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            UIColor.secondarySystemBackground.setFill()
            UIRectFill(rect)
            image.draw(in: rect)
        }
        thumbnailCache[record.id] = thumb
        return thumb
    }
}
