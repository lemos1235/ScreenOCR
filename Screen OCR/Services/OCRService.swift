import Foundation
import Vision
import AppKit

class OCRService {
    /// 执行OCR识别并返回识别结果，可指定语言
    /// - Parameters:
    ///   - image: 需要识别的图像
    ///   - languages: 需要识别的语言代码数组，如["zh-Hans", "en-US"]，传空数组表示自动检测
    ///   - completion: 完成回调，返回识别的文本及其位置信息
    func performOCR(on image: NSImage, languages: [String] = [], completion: @escaping ([OCRResult]) -> Void) {
        // 将NSImage转换为CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }
        
        // 创建请求处理器
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // 创建文本识别请求
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                print("OCR识别错误: \(error!.localizedDescription)")
                completion([])
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            // 处理结果
            let results = observations.compactMap { observation -> OCRResult? in
                // 获取最高置信度的识别结果
                let candidateCount = 3
                let candidates = observation.topCandidates(candidateCount)
                
                // 如果没有任何候选项，返回nil
                guard let topCandidate = candidates.first else { return nil }
                
                // 转换坐标系（Vision使用的是归一化坐标，左下角为原点）
                // NSView使用的坐标系是左上角为原点
                let boundingBox = CGRect(
                    origin: CGPoint(
                        x: observation.boundingBox.origin.x * CGFloat(cgImage.width),
                        y: (1 - observation.boundingBox.origin.y - observation.boundingBox.height) * CGFloat(cgImage.height)
                    ),
                    size: CGSize(
                        width: observation.boundingBox.width * CGFloat(cgImage.width),
                        height: observation.boundingBox.height * CGFloat(cgImage.height)
                    )
                )
                
                return OCRResult(
                    text: topCandidate.string,
                    boundingBox: boundingBox,
                    confidence: topCandidate.confidence
                )
            }
            
            completion(results)
        }
        
        // 配置请求
        request.revision = VNRecognizeTextRequestRevision3 // 使用最新的OCR模型
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // 设置支持的语言
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        } else {
            // 默认支持多种语言，将日语放在前列以优先识别
            request.recognitionLanguages = ["ja-JP", "ko-KR", "zh-Hans", "zh-Hant", "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ru-RU"]
            request.automaticallyDetectsLanguage = true
        }
        
        // 执行请求
        do {
            try requestHandler.perform([request])
        } catch {
            print("无法执行OCR请求: \(error.localizedDescription)")
            completion([])
        }
    }
}

/// OCR识别结果
struct OCRResult {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}
