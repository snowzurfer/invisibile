//
//  GIFToMOVConverter.swift
//  invisibile
//
//  Created by Alberto Taiuti in May 2023.
//

import AVFoundation
import CoreImage
import CoreGraphics
import VideoToolbox

/**
 In pixels.
 */
public let maxImageSize: CGFloat = 1024

/**
 Convert a GIF to a MOV, respecting transparency.
 
 Uses the HEVC with Alpha codec.
 */
public actor GIFToMOVConverter {
    private let assetWriter: AVAssetWriter
    public let temporaryFileURL: URL
    
    public enum ConverterError: Error {
        case error(reason: String)
    }
    
    public init() throws {
        temporaryFileURL = URL.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        assetWriter = try AVAssetWriter(outputURL: temporaryFileURL, fileType: .mov)
    }
    
    public func createVideo(from gifData: Data, resizedToMaxSize: CGFloat) async throws -> (size: CGSize, videoUrl: URL) {
        guard let source = CGImageSourceCreateWithData(gifData as CFData, nil) else {
            throw ConverterError.error(reason: "CGImageSourceCreateWithData returned nil")
        }
        
        let gifFramesCount = CGImageSourceGetCount(source)
        guard gifFramesCount > 0 else {
            throw ConverterError.error(reason: "no frames in GIF")
        }
        
        // Read the final size after we cap it
        let size = try calculateCappedSize(for: source, maxSize: resizedToMaxSize)
        
        // Create the adaptors
        let (writerInput, pixelBufferAdaptor) = makeAVWriterInputAndAdaptor(size: size)
        
        // Add the writer input to the asset writer
        assetWriter.add(writerInput)
        
        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        let ciContext = CIContext()
        // Loop through each frame and append it to the pixel buffer adaptor
        for i in 0..<gifFramesCount {
            // Add image
            guard let image = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                throw ConverterError.error(reason: "CGImageSourceCreateImageAtIndex at \(i) returned nil")
            }
            
            let ciImage = CIImage(cgImage: image)
            
            guard let resizedImage = resize(ciImage: ciImage, toSize: size) else {
                throw ConverterError.error(reason: "Failed to resize image at \(i)")
            }
            
            // Read the delay
            let delaySeconds = delayForImageAtIndex(Int(i), source: source)
            
            // Convert the CGImage to a CVPixelBuffer
            guard let pixelBuffer = pixelBuffer(from: resizedImage, using: pixelBufferAdaptor, ciContext: ciContext, frameSize: size) else {
                continue
            }
            
            // Create a presentation time for the frame
            let presentationTime = CMTime(seconds: delaySeconds * Double(i), preferredTimescale: 600)
            
            // Wait for the writer input to be ready for more media data
            while !writerInput.isReadyForMoreMediaData {
                usleep(1000)
            }
            
            // Append the pixel buffer with the presentation time
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
        
        // Finish writing
        writerInput.markAsFinished()
        await assetWriter.finishWriting()
        return (size, temporaryFileURL)
    }
    
    // MARK: Private utility functions
    private func calculateCappedSize(for source: CGImageSource, maxSize: CGFloat) throws -> CGSize {
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ConverterError.error(reason: "CGImageSourceCreateImageAtIndex at \(0) returned nil")
        }
        
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        
        let maxSize = CGFloat(min(Float(maxSize), (max(Float(height), Float(width)))))
        let imgRatio = width / height
        var size = CGSize(width: maxSize, height: maxSize / imgRatio)
        
        if height > width {
            size = CGSize(width: maxSize * imgRatio, height: maxSize)
        }
        
        return size
    }
    
    
    private func makeAVWriterInputAndAdaptor(size: CGSize) -> (writerInput: AVAssetWriterInput, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor) {
        // Create an AVAssetWriterInput
        // This value was chosen arbitrarily. You can tweak it
        let alphaQuality = 1
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey:
                [kVTCompressionPropertyKey_TargetQualityForAlpha: alphaQuality],
        ])
        
        // Create a pixel buffer attributes dictionary
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        // Create an AVAssetWriterInputPixelBufferAdaptor
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: attributes)
        
        return (writerInput, pixelBufferAdaptor)
    }
    
    private func resize(ciImage: CIImage, toSize size: CGSize) -> CIImage? {
        // Calculate the scale factors
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let scale = max(scaleX, scaleY)

        // Create an affine transform filter
        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey) // Preserve aspect ratio
        guard let scaledCIImage = scaleFilter.outputImage else {
            return nil
        }

        // Calculate origin for crop to maintain center of image
        let originX = (scaledCIImage.extent.width - size.width) / 2
        let originY = (scaledCIImage.extent.height - size.height) / 2
        let cropRect = CGRect(origin: CGPoint(x: originX, y: originY), size: size)

        // Center crop to required size
        let croppedCIImage = scaledCIImage.cropped(to: cropRect)
        
        return croppedCIImage
    }
    
    private func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        // Get dictionaries
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifPropertiesPointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 0)
        let unmanagedGifProperties = Unmanaged.passUnretained(kCGImagePropertyGIFDictionary)
        if CFDictionaryGetValueIfPresent(cfProperties, unmanagedGifProperties.toOpaque(), gifPropertiesPointer) {
            let gifProperties:CFDictionary = unsafeBitCast(gifPropertiesPointer.pointee, to: CFDictionary.self)
            var delayObject: AnyObject = unsafeBitCast(
                CFDictionaryGetValue(gifProperties,
                                     Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
                to: AnyObject.self)
            if delayObject.doubleValue == 0 {
                delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                                 Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
            }
            
            delay = delayObject as! Double
            // This makes sure they're not too fast
            if delay < 0.1 {
                delay = 0.1
            }
        }
        
        return delay
    }
    
    private func pixelBuffer(from ciImage: CIImage, using pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, ciContext: CIContext, frameSize: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                        pixelBufferAdaptor.pixelBufferPool!,
                                                        &pixelBuffer)
        guard status == kCVReturnSuccess, let finalPixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(finalPixelBuffer, [])
        
        // Render CIImage to CVPixelBuffer
        ciContext.render(ciImage, to: finalPixelBuffer, bounds: CGRect(origin: .zero, size: frameSize), colorSpace: ciImage.colorSpace)
        
        CVPixelBufferUnlockBaseAddress(finalPixelBuffer, [])
        
        return finalPixelBuffer
    }
}
