---
session_ids: [10025]
---

# Session 10025 - VisionKit 的 OCR 解决方案，更便捷的捕获文本与条码

本文基于 [Session 10025](https://developer.apple.com/videos/play/wwdc2022/10025/) 梳理。

> 作者：Layer（杨杰），就职于抖音 iOS 即时通讯团队，经常被可爱的人看到个人介绍。
>
> 审核：

## 需求场景：数据识别与扫描

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/data_scanner.png)

如今，光学字符识别（Optical Character Recognition，OCR）不断地发展，文本、条码等的识别和扫描应用也广泛普及。特别是移动终端设备的识别与扫描应用，越来越成为我们生活中不可或缺的一部分。对着文件扫一扫，就可以轻松录入为电子数据；对着商品上的二维码扫一扫，就可以方便的了解商品信息、进行支付交易等。

我们不拘泥于计算机科学上的定义，可以将这里所说的「数据识别与扫描」认为是读取来自于 iOS 设备相机提供的视频源中的文本、条码数据。我们可以将应用程序的这类功能称为“数据扫描仪”。

作为开发者，我们应如果构建自己的数据扫描仪？iOS SDK 为我们提供了多种解决方案，具体取决于我们的需求。我们将专注于如何实现这一功能。

## 内容概述：DataScanner

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_item.png)

本文将与大家一同认识 VisionKit 中的 `DataScannerViewController`。它结合了 AVCapture 和 Vision，通过简单的 Swift API 来实时的捕获视频源中的文本、条码。我们将展示如何通过「指定条码符号」或「选择语言类型」来控制应用程序可以捕获的内容，还将探讨如何同时在应用中启用用户指导、显示自定义项目、突出显示感兴趣区域，以及应用程序检测到项目后的处理与用户交互。同时，我们提供了其他方案的 Demo 来进行对比，从而更深入了解这些方案的差异。

## 相关背景：Vision & VisionKit

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/vision.png)

Vision 是 Apple 在 iOS 11 中引入的框架，框架提供人脸和人脸特征检测、文本检测、条码识别、图像配准和一般特征跟踪等能力。Vision 还允许将自定义 Core ML 模型用于分类或对象检测等任务。

VisionKit 是 Apple 在 iOS 13 中引入的框架，为 iOS 提供了图像和实时视频中的文本、结构化数据的检测功能。我们可以认为 VisionKit 是 Vision 的进一步封装，提供了一系列开箱即用的 API。使用 VisionKit，开发者无需手动的调整输入或进行检测，这些都会交给 VisionKit 处理。

- 有关静止的图像或暂停的视频帧与实时文本交互的更多信息，请观看来自 WWDC22 的另一个 Session “[Add Live Text interaction to your app](https://developer.apple.com/videos/play/wwdc2022/10026/)”。

- 其他相关资料可以参考：

    - [Vision Documentation](https://developer.apple.com/documentation/vision);

    - [visionkit Documentation](https://developer.apple.com/documentation/visionkit);

    - WWDC 2019 讲座 “[Understanding Images in Vision Framework](https://developer.apple.com/videos/play/wwdc2019/222/)”，了解 Vision 在图像分类、图像显著性、图像确定及面部捕捉质量评分等方面的改进；

    - WWDC 2019 讲座 “[Text Recognition in Vision Framework](https://developer.apple.com/videos/play/wwdc2019/234/)”，了解如何在应用程序中利用内置的机器学习技术，快速、准确的处理字符、语言的识别，以及它们之间的差异；

    - WWDC 2020 Session “[Explore Computer Vision APIs](https://developer.apple.com/videos/play/wwdc2020/10673/)”，了解如何将结合 Core Image、Vision 和 Core ML 的强大功能的计算机视觉智能引入我们的应用程序；

    - WWDC 2021 Session “[Extract document data using Vision](https://developer.apple.com/videos/play/wwdc2021/10041/)”，了解 Vision 如何提供专业的图像识别和分析，实现从文档中提取信息、识别多语言文本及条码；

    - 老司机技术周报 WWDC21 内参 “[使用 Vision 提取文档里的数据](https://xiaozhuanlan.com/topic/6204139578)”。
    
我们将从历史方案开始。

## 历史方案 1：AVFoundation

### 方案 1 介绍

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_flow_chart.png)

一种选择是我们可以使用 AVFoundation 框架。如图所示，将设备输入和设备输出，连接到会话，并对其进行配置，运行后生成扫描数据。

### 方案 1 Demo

> 这不是本 Session 的内容，但笔者实现了该方案的 Demo，供第一次接触的同学简单了解，并进行了简单的 Demo 录频演示及代码分解。

**演示录屏**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_demo.gif)

**代码分解**

除去用户授予程序访问相机的权限部分，我们来分段阅读代码，首先是简单的属性声明与 UI 布局逻辑：

```swift
import UIKit
import AVFoundation

class ViewController: UIViewController {

    // 1. 捕获会话，用来配置捕获行为、协调来自输入设备的数据流，以捕获输出的对象
    private var session: AVCaptureSession = AVCaptureSession()
    
    // 2. 显示来自相机设备的视频的 CALayer
    private var previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 3. 调整 UI 布局，并启动数据扫描
        view.layer.addSublayer(self.captureVideoPreviewLayer)
            previewLayer.frame = view.bounds
        start()
    }
    
    //...
}
```

接着是核心的的设备、输入流、输出流、会话链接及配置逻辑：

```swift
class ViewController: UIViewController {

    // ...
    
    private func start() {
        // 1. 获取捕获设备对象，捕获设备提供的媒体数据，单个设备可以提供一个或多个特定类型的媒体流
        guard let device = AVCaptureDevice.default(for: .video) else {
            assert(false, "Cevice error!")
            return
        }
        
        // 2. 从设备中捕获媒体输入，AVCaptureDeviceInput 类是用于将捕获设备连接到 Session 的具体子类
        guard let input = try? AVCaptureDeviceInput.init(device: device) else {
            assert(false, "Input error!")
            return
        }
        guard session.canAddInput(input) else {
            assert(false, "Can't add input!")
            return
        }
        session.addInput(input)
        
        // 3. 捕获会话生成的元数据的输出，一个拦截由其关联的捕获会话生成的元数据的对象
        let output = AVCaptureMetadataOutput.init()
        session.addOutput(output)
        guard session.canAddOutput(output) else {
            assert(false, "Can't add output!")
            return
        }
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
        output.metadataObjectTypes = [.qr]
        
        // 4. 调整 Layer 以展示捕获会话视频
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        
        // 5. 启动捕获会话
        session.startRunning()
    }
}
```

最后是处理生成的扫描数据：

```swift
extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    // 1. 处理捕获会话生成的元数据
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !metadataObjects.isEmpty,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr else {
            return
        }
        // 2. 更新 UI，进行弹窗提示
        DispatchQueue.main.async {
            let alert = UIAlertController.init(title: "Result", message: object.stringValue, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
```

> 这里只取 `metadataObjects.first` 只是 Demo 的偷懒方法，例如微信会提示多个扫码结果，欢迎读者对该部分进行深入尝试。
>
> AVMetadataMachineReadableCodeObject 的属性有 `var corners: [CGPoint]` 也可用于开发者绘制突出显示。但与 `DataScannerViewController` 提供的能力有一些差异，我们在后文将进行对比。
>
> 此外， `AVMetadataObject.ObjectType` 还可用于标识 Body（包括 humanBody、dogBody、dogBody）、Face 等原数据，可以参考文档 “[AVMetadataObject.ObjectType](https://developer.apple.com/documentation/avfoundation/avmetadataobject/objecttype)”。

## 历史方案 2：AVFoundation & Vision

### 方案 2 介绍

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_and_vision_flow_chart.png)

如果我们还想捕获文本，另一种选择是将 AVFoundation 和 Vision 框架结合在一起。在此图中，我们构建的不是元数据输出，而是视频数据输出。视频数据输出交付到样本缓冲区，这些缓冲区可以给到 VisionKit 用于文本和条形码识别请求，通过创建一个请求处理程序，调用相关算法，从而产生分析结果。

### 方案 2 Demo

> 这不是本 Session 的内容，但笔者实现了该方案的 Demo，供第一次接触的同学简单了解，并进行了简单的 Demo 录频演示及代码分解。

**演示录屏**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/acfoundation_and_vision_demo.gif)

**代码分解**

这部分我们重点关注与方案 1 的不同点，`output` 的类型使用 `AVCaptureVideoDataOutput` 而不是 `AVCaptureMetadataOutput`：

```swift
class ViewController: UIViewController {
    
    // ...
    
    func start() {
        // ...
        
        // 3. VideoData 捕获输出，使用此输出来处理来自捕获视频的压缩或未压缩帧
        let output = AVCaptureVideoDataOutput.init()
        guard session.canAddOutput(output) else {
            assert(false, "Can't add output!")
        }
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        
        // ...
    }
}
```

接下来，是 `AVCaptureVideoDataOutputSampleBufferDelegate` 部分：

```swift
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // 1. 构造文本识别算法请求
        let request = VNRecognizeTextRequest(completionHandler: textDetectHandler)
        
        // 2. 请求的语言支持、质量等级、语言矫正
        request.recognitionLanguages = ["en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // 3. 创建并执行一个请求处理程序，该处理程序对样本缓冲区中包含的图像执行请求
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer, orientation: .up, options: [:])
        do {
            try requestHandler.perform([request])
        } catch {
            assert(false, "Request error!")
        }
    }
    
    func textDetectHandler(request: VNRequest, error: Error?) {
        // 4. 文本识别请求的结果
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        let recognizedStrings = observations.compactMap { observation in
            // 5. 返回按置信度降序排序的第 1 个候选者
            print(observation.topCandidates(1).first?.string ?? "" + "\n")
            return observation.topCandidates(1).first?.string ?? "" + "\n"
        }
        // 6. 更新 UI
        DispatchQueue.main.async {
            if let text = recognizedStrings.first {
                self.textView.text += text
            }
        }
    }
}
```

以上两部分就是使用 AVFoundation 和 Vision 进行数据扫描的简短介绍和 Demo 实现。

## 进入正题 ：VisionKit

### 介绍 VisionKit 方案

在 iOS 16 中，Apple 提供了另一个新的选项可以为我们封装需要的功能。在 VisionKit 框架中引入了 `DataScannerViewController`。它结合了 AVFoundation 和 Vision 的特性，专门用于数据识别与扫描。 `DataScannerViewController` 可以实现**实时相机预览、展示用户指导标签、识别到的项目进行突出显示**、**点击聚焦**以及**捏拉缩放**等，有着作为原生能力的系统统一体验。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/datascanner_viewcontroller.png)

`DataScannerViewController` 是 `UIViewController` 的子类。识别到的项目的坐标始终位于视图坐标中，我们无需从图像空间转换为视觉坐标，再转换为视图坐标。我们还可以通过指定在视图坐标中的感兴趣区域，来限制视图的活动部分。对于文本识别，我们可以指定内容类型来进行识别限制。对于条码，可以准确指定要查找的符号或类型。

> 这里提到的坐标转换是与 Vision 进行对比，Vision 会为我们提供一个 `VNRecognizedObjectObservation`，继承自 `VNDetectedObjectObservation` ，包含一个 `boundingBox` 属性，带有被检测对象的边界框坐标。`boundingBox` 中的坐标被归一化，意味着 x、y、宽度和高度都是 0.0 到 1.0 之间的小数，同时原点 (0,0) 在左下角，这些都需要开发者进行转换。
>
> ![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/coordinates.png)

对于应用程序来说，数据扫描与识别可能只是其业务功能的一小部分，但需要开发者使用大量代码来实现该功能。使用 `DataScannerViewController`，让它为我们处理常见的数据扫描与识别任务，我们可以将精力集中在程序的其它地方。接下来，我们将尝试其添加到我们的应用程序中。

> 这里需要注意的是 `DataScannerViewController` 是 Swift Only 的，Objective-C 并不支持。

### 使用 VisionKit 方案

#### 隐私权限使用

和上述 Demo 一致，当应用程序尝试捕获视频时，iOS 会要求用户授予程序访问相机的明确权限。我们需要提供一条描述性消息来表明应用程序需求。请在应用的 Info.plist 文件中添加“Privacy - Camera Usage Description”。尽可能具有描述性，以便用户知道他们了解应用程序将使用什么。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/camera_ssage_description.png)

#### 支持及可用性检查

进入代码，无论我们想在哪里展示数据扫描仪，首先要导入 `VisionKit`。

```swift
import VisionKit
```

接下来，由于并非所有设备都支持数据扫描，因此 `isSupported` 类属性可以为应用程序隐藏功能入口。任何 2018 年及后续的配备 Apple 神经引擎的 iPhone（iPhone XS、iPhone XS Max、iPhone XR 及后续设备）和 iPad 设备（iPad Pro 2018 及后续设备）都支持该功能。

```swift
DataScannerViewController.isSupported
```

我们还需要检查可用性。除了用户批准应用程序访问相机，应用程序还需要不受任何限制。例如在屏幕时间的内容和隐私限制中，将相机的访问设置为没有限制。满足这些条件，我们则可以进行扫描。

```swift
DataScannerViewController.isAvailable
```

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/is_available.png)

现在我们已做好准备。

#### 配置数据扫描仪

首先，通过指定我们感兴趣的数据类型。例如，支持扫描二维码和文本。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
 .barcode(symbologies:[.qr]),
 .text() 
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)
```

我们可以传递语言列表，作语言校正等方面的提示。如果我们想支持多种语言，可以将它们加入到其中。如果我们不提供任何语言，其默认使用设备当前的语言。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(languages: ["ja"]) 
]
```

我们还可以请求特定的文本内容类型。在此示例中，希望扫描仪查找 URL。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: .URL) 
]
```

现在我们已经说明了要识别的数据类型，可以继续创建 `dataScanner` 实例。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: .URL)
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes) 
```

在前面的示例中，我们指定了条形码符号系统、识别语言和文本内容类型。我们来看看其他选项。

对于条码符号，其支持与 Vision 条码检测器同的符号。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_1.png)

在语言方面，作为 Live Text 功能的一部分，`DataScannerViewController` 支持完全相同的语言。在 iOS 16 中，Apple 会添加对日语和韩语的支持。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_2.png)

当然，这在未来可能会继续有新语言加入。可以使用 `supportedTextRecognitionLanguages` 类属性来检索最新的列表。

```swift
DataScannerViewController.supportedTextRecognitionLanguages
```

最后，在扫描具有特定语义含义的文本时，`DataScannerViewController` 可以找到这七种类型。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_3.png)

#### 展示数据扫描仪

我们现在已经准备好展示 `dataScanner`。像任何其他 `ViewController` 一样 `Present`，它将全屏显示，或者使用 `Sheet`，或者将其完全添加到另一个 `View` 中，完全取决于我们的需求。当 `Present` 完成后，调用 `startScanning()` 开始查找数据。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: .URL)
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)

// 展示数据扫描仪
present(dataScanner, animated: true) {
    try? dataScanner.startScanning() 
}
```

我们花一些时间来研究一下 `dataScanner` 的初始化参数。我们在这里使用了一个 `recognizedDataTypes`。还有其他一些方法可以帮助我们定制应用程序的体验，我们逐一来看：

- **`recognizedDataTypes`** 允许我们指定要识别的数据类型。文本、条码及其类型。

- **`qualityLevel`** 使用 `balanced`、`fast` 或者 `accurate`。例如，在阅读项目上，使用 `fast` 来牺牲分辨率从而提升速度。 `accurate` 将为我们提供最佳的准确性，即使遇到 micro QR 码等小物品，也可以非常从容。大多时候，更建议使用 `balanced`。

- **`recognizesMultipleItems`** 让我们可以选择查找一个或多个项目，比如我们想一次扫描多个条形码一样。当它为 `false` 时，默认情况下会识别最中心的项目，除非用户点击其它地方。

- **`isHighFrameRateTrackingEnabled`** 绘制高光时启用高帧率跟踪。当相机移动或场景变化时，它允许高光尽可能紧跟已经被扫描到的项目。

- **`isPinchToZoomEnabled`** 我们可以自行修改缩放级别。

- **`isGuidanceEnabled`** 是否在屏幕顶部显示指导用户的标签。

- **`isHighlightingEnabled`** 我们可以启用系统提供的突出显示，或者我们可以禁用它来绘制自定义的突出显示。

#### 提取已识别项目

我们已经了解如何展示数据扫描仪，那么让我们来谈谈我们将如何提取已识别的项目，以及如何绘制自定义高光。

首先，为 `dataScanner` 提供一个委托：

```swift
// 检索支持语言列表
print(DataScannerViewController.supportedTextRecognitionLanguages)

// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: .URL)
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)
dataScanner.delegate = self 
// 展示数据扫描仪
present(dataScanner, animated: true) {
    try? dataScanner.startScanning()
}
```

有了委托，我们可以实现 `dataScanner` 的 `didTapOn` 方法，该方法在用户点击项目时调用。有了它，我们将收到新类型 `RecognizeItem` 的实例。 `RecognizedItem` 是一个枚举，它保存文本或条形码作为关联值。

```swift
func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
    switch item {
    case .text(let text):
        print("text: (text.transcript)")
    case .barcode(let barcode):
        print("barcode: (barcode.payloadStringValue ?? "unknown")")
    default:
        print("unexpected item")
    }
}
```

对于文本，关联属性保存已识别的字符串的转录。对于条形码，可以使用 `payloadStringValue` 检索其有效负载包含的字符串。

有关 `RecognizedItem` 还有两件事：

1. 每个已识别的项目都有一个唯一标识符，我们可以使用它来跟踪项目的整个生命周期。该生命周期从第一次看到该项目开始，到不再出现时结束。

2. 每个 `RecognizedItem` 都有一个 `bounds` 属性。 `bounds` 不是 `frame`，它由四个点组成，每个角一个点。

> 这里的 `bounds` 是一个结构体，提供 `topLeft`、`topRight`、`bottomRight`、`bottomLeft` 四个属性，与上文提到的 `AVMetadataMachineReadableCodeObject` 的属性 `var corners: [CGPoint]` 相比，有更加明确的语义。

#### 已识别项目的变化

我们来看看屏幕中识别到的项目发生变化时，调用的三个相关委托方法。

第一个是 `didAdd`，当场景中的项目被新识别时调用。如果我们想创建自定义高光，可以在此处为每个新项目创建一个 `highLightView`。我们可以使用项目的 `ID` 来跟踪亮点。并且将 `highLightView` 添加到添加到 `dataScanner` 的 `overlayContainerView`，使其出现在相机预览上。

```swift
// 存储我们的自定义 HighlightView 的字典，其关联的项目 ID 作为 Key 值
var itemHighlightViews: [RecognizedItem.ID: HighlightView] = [:]

// 对于每个新项目，创建一个新的高亮视图并将其添加到视图层次结构中
func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    for item in addedItems {
        let newView = newHighlightView(forItem: item)
        itemHighlightViews[item.id] = newView
        dataScanner.overlayContainerView.addSubview(newView) 
    }
}
```

下一个委托方法是 `didUpdate`，它在项目移动或相机移动、以及识别到的文本到转录发生变化时被调用（扫描仪看到文本的时间越长，它的转录就越准确）。使用更新项目中的 `ID` 从我们刚刚创建的字典中检索我们的 `highLightView`，然后将视图动画化到它们新更新的 `bounds`。

```swift
// 动画方式将 HighlightView 移动到新 bounds
func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    for item in updatedItems {
        if let view = itemHighlightViews[item.id] {
            animted(view: view, toNewBounds: item.bounds) 
        }
    }
}
```

最后是 `didRemove` 委托方法，当项目在场景中不再可见时调用该方法。在此方法中，我们可以移除已删除项目的关联关系，并且可以将对应的 `highLightView` 从视图层次结构中删除。

```swift
// 高亮视图关联的项目被删除时
func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    for item in removedItems {
        if let view = itemHighlightViews[item.id] {
 itemHighlightViews.removeValue(forKey: item.id)   view.removeFromSuperview() 
        }
    }
}
```

总之，如果我们在项目上绘制自定义的突出显示，这三个委托方法对于我们控制动画高光入场、移动和删除，是至关重要的。对于这三个前面的委托方法中的每一个，我们还将获得一个包含当前识别的所有项目的数组。这对于文本识别可能会派上用场，比如这些项目按自然阅读顺序放置。

```swift
/// Called when the the scanner recognizes new items in the scene.
/// - Parameters:
///   - dataScanner: The DataScannerViewController object providing the update.
///   - addedItems: The newly recognized items.
///   - allItems: The new complete collection of items remaining after adding `addedItems`.
func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems : [ RecognizedItem ]) 

/// Called when the the scanner updates the geometry or content of an item previously recognized in the scene.
/// - Parameters:
///   - dataScanner: The DataScannerViewController object providing the update.
///   - updatedItems: the items that have been updated.
///   - allItems: The complete collection of items.
func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems : [ RecognizedItem ]) 

/// Called when the scanner no longer sees a previously recognized item in the scene.
/// - Parameters:
///   - dataScanner: The DataScannerViewController object providing the update.
///   - removedItems: The items that were removed.
///   - allItems: The new complete collection of items remaining after removing `removedItems`.
func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems : [ RecognizedItem ]) 
```

以上是如何使用 `DataScannerViewController` 的概述。

#### 其他功能

还有一些其它功能，比如拍照。我们可以调用 `capturePhoto` 方法，它会异步返回一个高质量的 `UIImage`。

```swift
// 拍摄静态照片并保存到相册
if let image = try? await dataScanner.capturePhoto()
UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
```

如果我们不创建自定义突出显示，就可能不需要上一部分的三个委托方法。我们可以使用 `RecognizedItem` 属性。它是一个 `AsyncStream`，会随着场景的变化而不断更新。

```swift
// 当识别的项目发生变化时发送通知
var currentItems: [RecognizedItem] = []
func updateViaAsyncStream() async {
    guard let scanner = dataScannerViewController else { return }
    let stream = scanner.recognizedItems
    for await newItems: [RecognizedItem] in stream {
        let diff = newItems.difference(from: currentItems) { a, b in         
            return a.id == b.id
        }
        if !diff.isEmpty {
            currentItems = newItems
            sendDidChangeNotification()
        }
    }
}
```

### VisionKit 方案 Demo

> 具体代码实现同上部分“使用”内容，本部分不进行代码分解。

**演示录屏（原生能力-图 1、自定义突出显示-图 2）**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/visionkit_demo_1.gif)![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/visionkit_demo_2.gif)

**点击事件输出**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/tap_output.png)

## 总结

iOS SDK 为我们提供了使用 AVFoundation 和 Vision 框架创建计算机视觉工作流的选项。也许我们正在创建一个使用实时视频源扫描文本或条码的应用程序，可以尝试使用 VisionKit 中的 `DataScannerViewController`，用它们来实现与系统应用程序风格相匹配的自定义扫描体验。
