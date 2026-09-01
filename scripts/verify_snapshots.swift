#!/usr/bin/env swift

import CoreGraphics
import Darwin
import Foundation
import ImageIO

struct SnapshotError: Error, CustomStringConvertible {
    let description: String
}

struct PNGImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

struct Attachment: Decodable {
    let suggestedHumanReadableName: String?
    let exportedFileName: String?
}

struct ManifestGroup: Decodable {
    let attachments: [Attachment]
}

struct Options {
    let baseline: URL
    let exported: URL
    let maxMean: Double
    let maxChanged: Double
    let topRows: Int
    let bottomRows: Int
    let pixelThreshold: Int
}

func argument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
        throw SnapshotError(description: "Falta el argumento \(name)")
    }
    return arguments[index + 1]
}

func parseOptions() throws -> Options {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let baseline = URL(fileURLWithPath: try argument("--baseline", in: arguments), isDirectory: true)
    let exported = URL(fileURLWithPath: try argument("--exported", in: arguments), isDirectory: true)

    func doubleOption(_ name: String, default value: Double) throws -> Double {
        guard let index = arguments.firstIndex(of: name) else { return value }
        guard arguments.indices.contains(index + 1), let parsed = Double(arguments[index + 1]) else {
            throw SnapshotError(description: "Valor inválido para \(name)")
        }
        return parsed
    }

    func intOption(_ name: String, default value: Int) throws -> Int {
        guard let index = arguments.firstIndex(of: name) else { return value }
        guard arguments.indices.contains(index + 1), let parsed = Int(arguments[index + 1]) else {
            throw SnapshotError(description: "Valor inválido para \(name)")
        }
        return parsed
    }

    return Options(
        baseline: baseline,
        exported: exported,
        maxMean: try doubleOption("--max-mean", default: 0.01),
        maxChanged: try doubleOption("--max-changed", default: 0.02),
        topRows: try intOption("--top-rows", default: 180),
        bottomRows: try intOption("--bottom-rows", default: 120),
        pixelThreshold: try intOption("--pixel-threshold", default: 32)
    )
}

func decodePNG(_ url: URL) throws -> PNGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw SnapshotError(description: "No se pudo leer \(url.path)")
    }

    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard didDraw else {
        throw SnapshotError(description: "No se pudo crear el buffer para \(url.path)")
    }
    return PNGImage(width: width, height: height, pixels: pixels)
}

func attachmentStem(_ name: String) -> String {
    if let range = name.range(of: "_0_") {
        return String(name[..<range.lowerBound])
    }
    return URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
}

func generatedImages(in exported: URL) throws -> [String: URL] {
    let manifestURL = exported.appendingPathComponent("manifest.json")
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode([ManifestGroup].self, from: manifestData)
    var images: [String: URL] = [:]

    for group in manifest {
        for attachment in group.attachments {
            guard let humanName = attachment.suggestedHumanReadableName,
                  let exportedName = attachment.exportedFileName else { continue }
            let stem = attachmentStem(humanName)
            guard images[stem] == nil else {
                throw SnapshotError(description: "Attachment duplicado en manifest: \(stem)")
            }
            images[stem] = exported.appendingPathComponent(exportedName)
        }
    }
    return images
}

func compare(
    baseline: PNGImage,
    current: PNGImage,
    topRows: Int,
    bottomRows: Int,
    pixelThreshold: Int
) throws -> (mean: Double, changed: Double) {
    guard baseline.width == current.width, baseline.height == current.height else {
        throw SnapshotError(
            description: "dimensiones distintas baseline=\(baseline.width)x\(baseline.height) "
                + "actual=\(current.width)x\(current.height)"
        )
    }
    guard topRows >= 0, bottomRows >= 0, topRows + bottomRows < baseline.height else {
        throw SnapshotError(description: "la máscara de sistema cubre toda la captura")
    }

    let width = baseline.width
    let firstRow = topRows
    let lastRow = baseline.height - bottomRows
    let pixelCount = (lastRow - firstRow) * width
    var differenceSum: UInt64 = 0
    var changedPixels = 0

    for row in firstRow..<lastRow {
        let rowStart = row * width * 4
        for pixel in 0..<width {
            let offset = rowStart + pixel * 4
            let red = abs(Int(baseline.pixels[offset]) - Int(current.pixels[offset]))
            let green = abs(Int(baseline.pixels[offset + 1]) - Int(current.pixels[offset + 1]))
            let blue = abs(Int(baseline.pixels[offset + 2]) - Int(current.pixels[offset + 2]))
            differenceSum += UInt64(red + green + blue)
            if max(red, green, blue) >= pixelThreshold {
                changedPixels += 1
            }
        }
    }

    let meanDifference = Double(differenceSum) / Double(pixelCount * 3 * 255)
    return (meanDifference, Double(changedPixels) / Double(pixelCount))
}

func run() throws {
    let options = try parseOptions()
    let fileManager = FileManager.default
    let baselineFiles = try fileManager.contentsOfDirectory(
        at: options.baseline,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension.lowercased() == "png" }
    guard !baselineFiles.isEmpty else {
        throw SnapshotError(description: "No hay PNGs baseline en \(options.baseline.path)")
    }

    let baselineImages = Dictionary(uniqueKeysWithValues: baselineFiles.map {
        ($0.deletingPathExtension().lastPathComponent, $0)
    })
    let currentImages = try generatedImages(in: options.exported)
    let baselineNames = Set(baselineImages.keys)
    let currentNames = Set(currentImages.keys)
    guard baselineNames == currentNames else {
        let missing = baselineNames.subtracting(currentNames).sorted().joined(separator: ", ")
        let unexpected = currentNames.subtracting(baselineNames).sorted().joined(separator: ", ")
        throw SnapshotError(description: "snapshot set mismatch; faltan=[\(missing)], sobran=[\(unexpected)]")
    }

    print("Comparando \(baselineImages.count) snapshots (máscara \(options.topRows)/\(options.bottomRows)px)")
    var failures: [String] = []
    for name in baselineNames.sorted() {
        let baseline = try decodePNG(baselineImages[name]!)
        let current = try decodePNG(currentImages[name]!)
        let result = try compare(
            baseline: baseline,
            current: current,
            topRows: options.topRows,
            bottomRows: options.bottomRows,
            pixelThreshold: options.pixelThreshold
        )
        print(String(format: "- %@: mean=%.6f, changed=%.4f%%", name, result.mean, result.changed * 100))
        if result.mean > options.maxMean || result.changed > options.maxChanged {
            failures.append(String(format: "%@ (mean=%.6f, changed=%.4f%%)", name, result.mean, result.changed * 100))
        }
    }

    guard failures.isEmpty else {
        throw SnapshotError(description: "Snapshots fuera de tolerancia: " + failures.joined(separator: ", "))
    }
    print("Snapshot baseline OK")
}

do {
    try run()
} catch {
    fputs("snapshot verification failed: \(error)\n", stderr)
    exit(1)
}
