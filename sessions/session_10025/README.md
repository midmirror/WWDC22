---
session_ids: [10025]
---

# Session 10025 - 使用 VisionKit 捕获机器可读的代码和文本

本文基于 [Session 10025](https://developer.apple.com/videos/play/wwdc2022/10025/) 梳理。

> 作者：Layer(杨杰)，就职于抖音 iOS 即时通讯团队。一不小心吃胖了导致退役的 Coser，经常被可爱的人看到个人介绍。
>
> 审核：

## 内容概述：DataScanner

本文将与大家一同认识 VisionKit 中的 DataScanner。该框架结合了 AVCapture 和 Vision，可通过简单的 Swift API 来实时的捕获机器可读的代码和文本。我们将展示如何通过「指定条形码符号」或「选择语言类型」来控制应用程序可以捕获的内容。我们还将探讨如何在应用中同时启用指导、显示自定义项目或突出显示感兴趣区域，以及在应用检测到项目后的交互处理。

> 有关静止的图像或暂停的视频帧与实时文本交互的更多信息，请观看来自 WWDC22 的另一个 Session “[Add Live Text interaction to your app](https://developer.apple.com/videos/play/wwdc2022/10026/)”。

## 相关背景：VisionKit

VisionKit 是 Apple 在 iOS 13 中引入的新框架，提供了图像和 iOS 摄像头的实时视频中的文本和结构化数据的检测。使用 VisionKit，则无需开发者手动的调整输入或进行检测，这些都会交给 VisionKit 处理。开发者可以专注于应用程序的其他部分。
> 了解 VisionKit 的详细内容请参考 [VisionKit Documentation](https://developer.apple.com/documentation/visionkit)


## 引入问题：数据扫描

我们将讨论如何从视频源中捕获设备可读的代码和文本，或者称之为数据扫描。 这里所说的「数据扫描」到底是指什么？这是一种使用传感器（如相机）读取数据的方式。
通常，这些数据以文本的形式出现。 例如，包含电话号码、日期和价格等信息的收据。数据还可以是机器可读的代码，比如无处不在的二维码。 

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/data_scanner.png)

我们以前肯定使用过数据扫描仪，可能是“相机”应用程序，或者使用 iOS 15 中引入的实时文本功能。更或者在日常生活中使用过的开发商自定义扫描的应用程序。 作为开发者，如果我们必须构建自己的数据扫描仪怎么办？ iOS SDK 为我们提供了不止一种解决方案，具体取决于我们的需求。

## 历史方案 1：AVFoundation

### 介绍

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_flow_chart.png)

一种选择是我们可以使用 AVFoundation 框架。如图所示，将设备（AVCaptureDevice）输入（AVCaptureDevicelnput）和设备输出（AVCaptureMetadataOutput），连接到会话（AVCaptureSession），并对其进行配置（AVCaptureConnection）,生成 扫描数据（AVMetadataObjects）。

### Demo

> 这不是本 Session 的内容，但笔者实现了该方案的 Demo，供第一次接触的同学简单了解，并进行了简单的 Demo 录频演示及代码分解。

**演示录屏**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_demo.gif)

**代码分解**

```swift
import UIKit
import AVFoundation

class ViewController: UIViewController {

    // 1
    lazy var session: AVCaptureSession = {
        return AVCaptureSession.init()
    }()
    
    // 2
    lazy var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer = {
        return AVCaptureVideoPreviewLayer.init()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 3
        view.layer.addSublayer(self.captureVideoPreviewLayer)
        captureVideoPreviewLayer.frame = view.bounds
        start()
    }
    
    //...
}
```

1. 捕获会话，用来配置捕获行为、协调来自输入设备的数据流，以捕获输出的对象；
2. 显示来自相机设备的视频的 `CoreAnimationLayer`；
3. 调整 UI 布局，并启动数据扫描。


```swift
class ViewController: UIViewController {

    // ...
    
    func start() {
        // 1
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            assert(false, "CaptureDevice error!")
            return
        }
        
        // 2
        guard let captureDeviceInput = try? AVCaptureDeviceInput.init(device: captureDevice) else {
            assert(false, "CaptureDeviceInput error!")
            return
        }
        session.addInput(captureDeviceInput)
        
        // 3
        let captureDeviceOutput = AVCaptureMetadataOutput.init()
        session.addOutput(captureDeviceOutput)
        captureDeviceOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .default))
        print(captureDeviceOutput.availableMetadataObjectTypes)
        captureDeviceOutput.metadataObjectTypes = [.qr]
        
        // 4
        captureVideoPreviewLayer.session = session
        captureVideoPreviewLayer.videoGravity = .resizeAspectFill
        
        // 5
        session.startRunning()
    } 
}
```

1. 获取捕获设备对象，捕获设备提供的媒体数据，单个设备可以提供一个或多个特定类型的媒体流；
2. 从设备中捕获媒体输入，`AVCaptureDeviceInput` 类是用于将捕获设备连接到 `Session` 的具体子类；
3. 捕获会话生成的元数据的输出，一个拦截由其关联的捕获会话生成的元数据的对象；
4. 调整 `CoreAnimationLayer` 以展示捕获会话视频；
5. 启动捕获会话。


```swift
extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    // 1
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !metadataObjects.isEmpty,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr else {
            return
        }
        // 2
        DispatchQueue.main.async {
            let alert = UIAlertController.init(title: "Result", message: object.stringValue, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
```

1. 处理捕获会话生成的元数据；
2. 更新 UI，进行弹窗提示。


## 历史方案 2：AVFoundation & Vision 

### 介绍

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/avfoundation_and_vision_flow_chart.png)

如果我们还想捕获文本，另一种选择是将 AVFoundation 和 Vision 框架结合在一起。在此图中，我们创建的不是元数据输出，而是视频数据输出（AVCaptureVideoDataOutput）。视频数据输出导致样本缓冲区的交付（CMSampleBufferRef），这些缓冲区可以给到 VisionKit 以用于文本和条形码识别请求，通过创建一个请求处理程序（VNImageRequestHandler），调用相关算法（VNDetectBarcodesRequest、VNRecognizeTextRequest），从而产生 VisionObservation（VNBarcodeObservation、VNRecognizedTextObservation）。

> 有关使用 Vision 进行数据扫描的更多信息，请查看 WWDC21 中的 “[Extract document data using Vision](https://developer.apple.com/videos/play/wwdc2021/10041/)”

### Demo

> 这不是本 Session 的内容，但笔者实现了该方案的 Demo，供第一次接触的同学简单了解，并进行了简单的 Demo 录频演示及代码分解。

**演示录屏**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/acfoundation_and_vision_demo.gif)

**代码分解**

```swift
import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    // 1
    lazy var session: AVCaptureSession = {
        return AVCaptureSession.init()
    }()
    
    // 2
    lazy var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer = {
        return AVCaptureVideoPreviewLayer.init()
    }()
    
    // 3
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        return textView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 4
        view.layer.addSublayer(captureVideoPreviewLayer)
        captureVideoPreviewLayer.frame = view.bounds
        
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16.0),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16.0),
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 56.0),
            textView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        start()
    }
    
    // ...

}
```

1. 捕获会话，用来配置捕获行为，并协调来自输入设备的数据流，以捕获输出的对象；
2. 显示来自相机设备的视频的 `CoreAnimationLayer`；
3. 显示使用的 UITextView；
4. 调整 UI 布局，启动数据扫描。


```swift
class ViewController: UIViewController {
    
    // ...
    
    func start() {
        // 1
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            assert(false, "CaptureDevice error!")
            return
        }
        
        // 2
        guard let captureDeviceInput = try? AVCaptureDeviceInput.init(device: captureDevice) else {
            assert(false, "CaptureDeviceInput error!")
            return
        }
        session.addInput(captureDeviceInput)
        
        // 3
        let captureVideoDataOutput = AVCaptureVideoDataOutput.init()
        session.addOutput(captureVideoDataOutput)
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        
        // 4
        captureVideoPreviewLayer.session = session
        captureVideoPreviewLayer.videoGravity = .resizeAspectFill
        
        // 5
        session.startRunning()
    }
}
```

1. 获取捕获设备对象；捕获设备提供媒体数据，单个设备可以提供一个或多个特定类型的媒体流；
2. 从设备中捕获媒体输入；`AVCaptureDeviceInput` 类是用于将捕获设备连接到 `Session` 的具体子类；
3. `VideoData` 捕获输出，使用此输出来处理来自捕获视频的压缩或未压缩帧；
4. 调整 `CoreAnimationLayer` 以展示捕获会话视频；
5. 启动捕获会话。


```swift
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // 1
        let requestHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .down)
        
        // 2
        let request = VNRecognizeTextRequest(completionHandler: textDetectHandler)
        do {
            try requestHandler.perform([request])
        } catch {
            assert(false, "Request error!")
        }
    }
    
    func textDetectHandler(request: VNRequest, error: Error?) {
        // 3
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        let recognizedStrings = observations.compactMap { observation in
            // 4
            return observation.topCandidates(1).first?.string
        }
        // 5
        DispatchQueue.main.async {
            if let text = recognizedStrings.first {
                self.textView.text += text
            }
        }
    }
}
```

1. 创建一个请求处理程序，该处理程序对样本缓冲区中包含的图像执行请求；
2. 构造文本识别算法请求；
3. 文本识别请求的结果；
4. 返回按置信度降序排序的第 1 个候选者；
5. 更新 UI。

以上就是使用 AVFoundation 和 Vision 进行数据扫描的简短介绍和 Demo 实现。

## 进入正题 ：VisionKit

### 介绍

在 iOS 16 中，Apple 提供了另一个新选项可以为我们封装所有这些。在 VisionKit 框架中引入 `DataScannerViewController`。它结合了 AVFoundation 和 Vision 的特性，专门用于数据扫描。 DataScannerViewController 可以进行**实时相机预览、有用的指导标签、项目突出显示**、**点击聚焦**、**捏拉缩放**等。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/datascanner_viewcontroller.png)

`DataScannerViewController` 是 `UIViewController` 的子类。识别到的项目的坐标始终位于视图坐标中，我们无需从图像空间转换为视觉坐标，再转换为视图坐标。我们还可以通过指定在视图坐标中的感兴趣区域，来限制视图的活动部分。对于文本识别，我们可以指定内容类型来限制找到的文本类型。对于机器可读的代码，可以准确指定要查找的符号或类型。

常规来讲，对于我们的应用程序来说，数据扫描只是其功能的一小部分。但它可能需要大量代码。使用 `DataScannerViewController`，其为我们执行常见任务，我们可以将时间集中在其它地方。接下来，我们将尝试其添加到我们的应用程序中。

### 使用

#### 隐私权限使用

和上述 Demo 一致，当应用程序尝试捕获视频时，iOS 会要求用户授予程序访问相机的明确权限。我们需要提供一条描述性消息来表明应用程序需求。为此，请在应用的 Info.plist 文件中添加“Privacy - Camera Usage Description”。尽可能具有描述性，以便用户知道他们了解应用程序将使用什么。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/camera_ssage_description.png)

#### 支持及可用性检查

进入代码，无论我们想在哪里展示数据扫描仪，首先要导入 `VisionKit`。

```swift
import VisionKit
```

接下来，由于并非所有设备都支持数据扫描，因此使用 `isSupported` 类属性来隐藏任何相关功能的按钮或菜单，这样用户就不会看到他们无法使用的东西。任何 2018 年及后续的配备 Apple 神经引擎的的 iPhone 和 iPad 设备都支持数据扫描。

```swift
DataScannerViewController.isSupported
```

我们还需要检查可用性。除了用户批准应用程序访问相机，设备还需要不受任何限制。例如在屏幕时间的内容和隐私限制中设置的相机访问没有限制。满足这些条件，我们则可以进行扫描。

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
 .barcode(symbologies:[.qr]),   .text() 
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)
```

我们可以选择传递语言列表，供文本识别器用作语言校正等方面的提示。如果我们想支持多种语言，请将它们加入到其中。如果我们不提供任何语言，其默认使用设备当前的语言。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(languages: ["ja"]) 
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)
```

我们还可以请求特定的文本内容类型。在此示例中，希望扫描仪查找 URL。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: . URL) 
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController(recognizedDataTypes: recognizedDataTypes)
```

现在我们已经说明了要识别的数据类型，可以继续创建 DataScanner 实例。

```swift
// 指定要识别的数据类型
let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
    .barcode(symbologies:[.qr]),
    .text(textContentType: .URL)
]

// 创建数据扫描仪
let dataScanner = DataScannerViewController (recognizedDataTypes: recognizedDataTypes) 
```

在前面的示例中，我们指定了条形码符号系统、识别语言和文本内容类型。我们来看看其他选项。

对于条码符号，其支持与 Vision 条码检测器相同的符号。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_1.png)

在语言方面，作为 LiveText 功能的一部分，`DataScannerViewController` 支持完全相同的语言。在 iOS 16 中，Apple 正在添加对日语和韩语的支持。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_2.png)

当然，这在未来可能会再次改变。所以使用 `supportedTextRecognitionLanguages` 类属性来检索最新的列表。

```
DataScannerViewController.supportedTextRecognitionLanguages
```

最后，在扫描具有特定语义含义的文本时，`DataScannerViewController` 可以找到这七种类型。

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_data_type_3.png)

#### 展示数据扫描仪

我们现在已经准备好向用户展示 DataScanner。像任何其他 `ViewController` 一样 `Present`，它将全屏显示，或者使用 `Sheet`，或者将其完全添加到另一个 `View` 中。完全取决于我们的需求。之后，当 `Present` 完成后，调用 `startScanning()` 开始查找数据。

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
    try?  dataScanner.startScanning() 
}
```

退后一步，我们花一些时间来研究一下 DataScanner 的初始化参数。我们在这里使用了一个 `recognizedDataTypes`。还有其他一些方法可以帮助我们定制应用程序的体验。我们逐一来看。

-   **recognizedDataTypes**：允许我们指定要识别的数据类型。文本、机器可读代码以及每种代码的类型。
-   **qualityLevel：** 使用 ****balanced、fast 或者 accurate。例如，在阅读项目上，使用 “fast” 来牺牲分辨率从而提升速度。 accurate 将为我们提供最佳的准确性，即使遇到 micro QR 码或小序列号等小物品，也可以非常从容。大多时候，更建议使用 balanced。
-   **recognizesMultipleItems：** 让我们可以选择查找一个或多个项目，比如我们想一次扫描多个条形码一样。当它为 false 时，默认情况下会识别最中心的项目，除非用户点击其他地方。
-   **isHighFrameRateTrackingEnabled** 绘制高光时启用高帧率跟踪。当相机移动或场景变化时，它允许高光尽可能紧跟已经被扫描到的项目。
-   **isPinchToZoomEnabled** 我们可以自行修改缩放级别。
-   **isGuidanceEnabled** 是否在屏幕顶部显示标签以指导用户。
-   **isHighlightingEnabled** 我们可以启用系统提供的突出显示，或者我们可以禁用它来绘制自定义突出显示。

#### 提取已识别项目

我们已经了解如何展示数据扫描仪，那么让我们来谈谈我们将如何提取已识别的项目，以及如何绘制自定义高光。

首先，为 dataScanner 提供一个委托。

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

有了委托，我们可以实现 dataScanner 的 `didTapOn` 方法，该方法在用户点击项目时调用。有了它，我们将收到新类型 `RecognizeItem` 的实例。 `RecognizedItem` 是一个枚举，它保存文本或条形码作为关联值。

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

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/recognized_item.png)

#### 已识别项目的变化

我们来看看屏幕中识别到的项目发生变化时，调用的三个相关委托方法。

第一个是 didAdd，当场景中的项目被新识别时调用。如果我们想创建自己的自定义高光，可以在此处为每个新项目创建一个 `highLightView`。我们可以使用项目的 ID 来跟踪亮点。并且将 `highLightView` 添加到添加到 DataScanner 的 `overlayContainerView`，以便它们出现在相机预览上方。

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

下一个委托方法是 `didUpdate`，它在项目移动或相机移动、以及识别到的文本到转录发生变化时被调用（扫描仪看到文本的时间越长，它的转录就越准确）。使用更新项目中的 ID 从我们刚刚创建的字典中检索我们的 `highLightView`，然后将视图动画化到它们新更新的 `bounds`。

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

总之，如果我们在项目上绘制自己的突出显示，这三个委托方法对于我们控制动画高光进入场景、动画它们的移动和动画它们是至关重要的。对于这三个前面的委托方法中的每一个，我们还将获得一个包含当前识别的所有项目的数组。这对于文本识别可能会派上用场，因为这些项目按其自然阅读顺序放置。

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

这是如何使用 `DataScannerViewController` 的概述。

#### 其他功能

还有一些其它功能，比如拍照。我们可以调用 `capturePhoto` 方法，它会异步返回一个高质量的 `UIImage`。

```swift
// 拍摄静态照片并保存到相册
if let image = try? await dataScanner.capturePhoto()
UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
```

如果我们不创建自定义突出显示，则可能不需要上一部分的三个委托方法。相反，我们可以使用 `RecognizedItem` 属性。它是一个 `AsyncStream`，会随着场景的变化而不断更新。

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

### Demo

> 具体代码实现同上部分“使用”内容，本部分不进行代码分解。

**演示录屏（原生能力-图 1、自定义突出显示-图 2）**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/visionkit_demo_1.gif)![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/visionkit_demo_2.gif)

**点击事件输出**

![](https://raw.githubusercontent.com/LLLLLayer/picture-bed/main/img/wwdc22/session10025/tap_output.png)

## 总结

iOS SDK 为我们提供了使用 AVFoundation 和 Vision 框架创建计算机视觉工作流的选项。 也许我们正在创建一个使用实时视频源扫描文本或机器可读代码的应用程序，可以尝试使用 VisionKit 中的 `DataScannerViewController`，我们可以使用它们来提供与您的应用程序风格和需求相匹配的自定义体验。

最后，欢迎了解另一个 Session “[Add Live Text interaction to your app](https://developer.apple.com/videos/play/wwdc2022/10026/)”，我们可以在其中了解 VisionKit 针对静态图像的实时文本功能。
