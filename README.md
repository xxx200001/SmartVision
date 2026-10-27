# 慧眼识图 SmartVision

基于 Core ML 的智能识图相册（iOS 创意作业作品）。对课程 ImageRecog（图像识别）与 InfoList（信息列表）两个实验的系统性改进与融合：拍一张照片或从相册选图，App 在**完全离线**的前提下给出 Top-5 候选类别与置信度条形图（中文优先展示），并可保存为「识图历史」，随时翻阅、回放、删除。

## 功能特性

- **双输入源**：相机 / 相册；模拟器无相机时给出友好提示而非闪退
- **Top-5 置信度可视化**：自定义 `UIView` 子类 + CoreGraphics 绘制条形图，深浅色模式自适应
- **识别结果中文化**：内置 660 余条 ImageNet 类别中文词典，三级匹配（整串 → 首同义词 → 回退英文）
- **识图历史持久化**：`NSCoding` + `NSKeyedArchiver` 归档，照片文件统一管理，支持增、删、查、回放
- **性能优化**：大图先降采样至最长边 1024px，Core ML 推理放入后台队列，主线程只负责刷新

## 运行要求

- Xcode 16 及以上（工程使用 Xcode 16 的文件夹同步工程格式）
- iOS 15.0+，任一 iPhone 模拟器即可运行；相机功能需真机

## 构建步骤

1. 双击 `SmartVision.xcodeproj` 打开工程；
2. 顶部选择任一 iPhone 模拟器，`Cmd + R` 运行（首次编译需将 mlmodel 生成模型类，约半分钟）；
3. 模拟器内用 Safari 保存几张图片到相册即可完整演示；真机调试用免费个人 Apple ID 即可。

## 模型说明

`SmartVision/Resnet50.mlmodel` 为**课程下发**的 Core ML 模型（Apple ResNet50，ImageNet 1000 类，约 102 MB）。
该文件超过 GitHub 单文件 50 MB 硬限制（100 MB 拒收），如需托管本仓库请任选其一：

```bash
# 方案一：Git LFS
git lfs install
git lfs track "*.mlmodel"
git add .gitattributes SmartVision/Resnet50.mlmodel
git commit -m "chore: track mlmodel with Git LFS"

# 方案二：不入库，README 说明来源（课程下发），由使用者自行放置
```

## 工程结构

```
SmartVision/
├── App/                      # AppDelegate / SceneDelegate（纯代码搭建窗口）
├── Controllers/
│   ├── RecognizeViewController.swift   # 识别页：选图 → Core ML 推理 → Top-5 展示 → 保存
│   └── HistoryTableViewController.swift# 历史页：动态表视图 + 编辑删除 + 点选回放
├── Model/
│   ├── VisionRecord.swift    # 记录模型（NSCoding）
│   ├── RecordStore.swift     # 记录仓库单例：归档读写 + 照片文件管理
│   └── Labels.swift          # ImageNet 类别中文词典与翻译逻辑
├── Views/
│   └── ConfidenceChartView.swift      # 自定义视图：draw(_:) 绘制置信度条形图
└── Resnet50.mlmodel          # 课程下发的 Core ML 模型
```

## 测试要点

见实验报告「4.3 测试计划」：相册选图、相机不可用提示、保存/回放/删除、持久化重启、深色模式、空状态、词典回退共 10 项。

## 许可与说明

仅用于课程作业（学号 21241513 · 薛剑）。应用所有数据仅存本地，不采集任何用户信息。
