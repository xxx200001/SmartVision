import UIKit
import CoreML
import Vision

/// 识别页（主页面）：选图 → 识别 → 展示 Top-5 → 可存入识图历史
/// 借鉴课堂 ImageRecog 实验（C12 Machine Learning），在其基础上做了多项改进，
/// 见实验报告「一、构思」中的改进点对照表。
final class RecognizeViewController: UIViewController {

    // MARK: UI（代码化布局；锚点约束与课堂 AutoLayout 的 Pin 语义等价）
    private let photoView = UIImageView()
    private let chartView = ConfidenceChartView()
    private let saveButton = UIButton(type: .system)

    // MARK: 状态
    private var currentImage: UIImage?
    private var currentResults: [ConfidenceChartView.Item] = []
    private var currentEnglish = ""
    private var currentTopFivePayload = ""

    /// 课堂写法：把 Core ML 模型包装为可被 Vision 调用的模型
    private let resnetModel = Resnet50()

    // MARK: 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "慧眼识图"

        // 导航栏按钮：相机（系统 Camera 图标）、相册（系统 Organize 图标，课堂 C12 用法）、历史
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .camera,
                            target: self, action: #selector(cameraTapped)),
            UIBarButtonItem(barButtonSystemItem: .organize,
                            target: self, action: #selector(albumTapped))
        ]
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "历史", style: .plain,
                                                            target: self,
                                                            action: #selector(historyTapped))

        setupLayout()
        updateSaveState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从「识图历史」点选记录回来 → 回放该记录
        if let record = RecordStore.shared.pendingShow {
            RecordStore.shared.pendingShow = nil
            replay(record: record)
        }
    }

    // MARK: 布局（NSLayoutAnchor 代码化 AutoLayout）
    private func setupLayout() {
        photoView.backgroundColor = .secondarySystemBackground
        photoView.layer.cornerRadius = 14
        photoView.clipsToBounds = true
        photoView.contentMode = .center
        photoView.tintColor = .tertiaryLabel
        photoView.image = UIImage(systemName: "photo.on.rectangle.angled")
        photoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(photoView)

        chartView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chartView)

        saveButton.setTitle("保存到识图历史", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        saveButton.tintColor = .systemBlue
        saveButton.layer.cornerRadius = 12
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            photoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            photoView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            photoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            photoView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),

            chartView.topAnchor.constraint(equalTo: photoView.bottomAnchor, constant: 10),
            chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            chartView.heightAnchor.constraint(equalToConstant: 195),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),

            chartView.bottomAnchor.constraint(lessThanOrEqualTo: saveButton.topAnchor, constant: -8)
        ])
    }

    private func updateSaveState() {
        let enabled = currentImage != nil && !currentResults.isEmpty
        saveButton.isEnabled = enabled
        saveButton.alpha = enabled ? 1 : 0.4
    }

    // MARK: Actions
    @objc private func cameraTapped() {
        // 改进：支持相机输入，并检测可用性（模拟器无相机时给出提示，课堂原版只支持相册）
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "相机不可用",
                      message: "当前设备（模拟器）没有相机，请改用旁边的「相册」按钮选择照片。")
            return
        }
        presentPicker(sourceType: .camera)
    }

    @objc private func albumTapped() {
        presentPicker(sourceType: .photoLibrary)
    }

    @objc private func historyTapped() {
        // 模态呈现历史页（课堂 InfoList 的 Present Modally 模式，改用代码创建）
        let history = HistoryTableViewController()
        present(UINavigationController(rootViewController: history), animated: true)
    }

    @objc private func saveTapped() {
        guard let image = currentImage, !currentResults.isEmpty,
              let fileName = RecordStore.shared.saveImage(image) else {
            showAlert(title: "保存失败", message: "照片写入失败，请重试。")
            return
        }
        let top1 = currentResults[0]
        let record = VisionRecord(title: top1.name,
                                  english: currentEnglish,
                                  confidence: top1.confidence,
                                  topFive: currentTopFivePayload,
                                  imagePath: fileName)
        RecordStore.shared.add(record)
        showAlert(title: "已保存", message: "记录「\(top1.name)」已加入识图历史。")
    }

    // MARK: 照片选取（与课堂一致的 UIImagePickerController + Delegate）
    private func presentPicker(sourceType: UIImagePickerController.SourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }

    // MARK: 识别（CoreML + Vision）
    private func classifyPicture(image: UIImage) {
        chartView.items = []
        updateSaveState()

        // 改进：大图先降采样到最长边 1024，避免 4K 照片识别卡顿
        let scaled = resized(image, maxSide: 1024)
        guard let cgImage = scaled.cgImage else { return }

        guard let visionModel = try? VNCoreMLModel(for: resnetModel.model) else { return }

        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, _ in
            guard let self = self,
                  let results = request.results as? [VNClassificationObservation],
                  !results.isEmpty else { return }

            let top = results.prefix(5)
            let items = top.map { observation in
                ConfidenceChartView.Item(name: Labels.displayName(for: observation.identifier),
                                         confidence: Double(observation.confidence))
            }
            // 分隔符用分号：ImageNet 标签本身常含逗号（如 "sunglasses, dark glasses"）
            let payload = top.map {
                "\($0.identifier)|\(String(format: "%.4f", $0.confidence))"
            }.joined(separator: ";")

            // 回到主线程刷新 UI（识别在后台队列完成）
            DispatchQueue.main.async {
                self.currentImage = image
                self.currentResults = items
                self.currentEnglish = top.first?.identifier ?? ""
                self.currentTopFivePayload = payload
                self.photoView.image = image
                self.photoView.contentMode = .scaleAspectFit
                self.chartView.items = items
                self.updateSaveState()
            }
        }
        request.imageCropAndScaleOption = .centerCrop

        // 改进：识别放到后台队列，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: 历史回放
    private func replay(record: VisionRecord) {
        if let image = RecordStore.shared.loadImage(named: record.imagePath) {
            currentImage = image
            photoView.image = image
            photoView.contentMode = .scaleAspectFit
        }
        let items = record.chartItems()
        currentResults = items
        currentEnglish = record.english
        currentTopFivePayload = record.topFive
        chartView.items = items
        updateSaveState()
    }

    // MARK: 工具
    private func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func showAlert(title: String, message: String) {
        // 课堂练习 1 的 UIAlertController 用法
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate（课堂协议写法）
extension RecognizeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            classifyPicture(image: image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
