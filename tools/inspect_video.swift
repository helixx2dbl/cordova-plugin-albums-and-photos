import Foundation
import AVFoundation
import CoreMedia

func fourcc(_ v: FourCharCode) -> String {
    let b = [UInt8(v >> 24 & 0xff), UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff)]
    return String(bytes: b, encoding: .ascii) ?? "?"
}
func t(_ x: CMTime) -> String { return String(format: "%.4f", CMTimeGetSeconds(x)) }

for path in CommandLine.arguments.dropFirst() {
    print("==== \(path)")
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    print("duration \(t(asset.duration))  tracks \(asset.tracks.count)  preferredRate \(asset.preferredRate)")
    for track in asset.tracks {
        print("-- track \(track.trackID) \(track.mediaType.rawValue) enabled=\(track.isEnabled) playable=\(track.isPlayable) selfContained=\(track.isSelfContained)")
        print("   timeRange \(t(track.timeRange.start))..\(t(track.timeRange.duration)) nominalFps \(track.nominalFrameRate) minDur \(t(track.minFrameDuration)) dataRate \(Int(track.estimatedDataRate/1000))kbps naturalSize \(track.naturalSize) transform \(track.preferredTransform)")
        for seg in track.segments {
            print("   segment empty=\(seg.isEmpty) source \(t(seg.timeMapping.source.start))+\(t(seg.timeMapping.source.duration)) -> target \(t(seg.timeMapping.target.start))+\(t(seg.timeMapping.target.duration))")
        }
        for fd in track.formatDescriptions as! [CMFormatDescription] {
            let mt = CMFormatDescriptionGetMediaType(fd)
            let st = CMFormatDescriptionGetMediaSubType(fd)
            print("   format \(fourcc(mt))/\(fourcc(st))")
            if mt == kCMMediaType_Video {
                let d = CMVideoFormatDescriptionGetDimensions(fd)
                print("     dims \(d.width)x\(d.height)")
            }
            if mt == kCMMediaType_Audio, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd)?.pointee {
                print("     audio rate \(asbd.mSampleRate) channels \(asbd.mChannelsPerFrame) formatFlags \(asbd.mFormatFlags) framesPerPacket \(asbd.mFramesPerPacket)")
                if let layout = CMAudioFormatDescriptionGetChannelLayout(fd, sizeOut: nil) {
                    print("     channelLayoutTag \(layout.pointee.mChannelLayoutTag)")
                }
            }
            if let ext = CMFormatDescriptionGetExtensions(fd) as? [String: Any] {
                let keys = ext.keys.sorted()
                print("     extension keys: \(keys.joined(separator: ", "))")
                for k in ["CVImageBufferColorPrimaries","CVImageBufferTransferFunction","CVImageBufferYCbCrMatrix","CVFieldCount","CVPixelAspectRatio","ColorPrimaries","TransferFunction","YCbCrMatrix","FullRangeVideo","BitsPerComponent","Depth","CVImageBufferChromaLocationTopField","SampleDescriptionExtensionAtoms"] {
                    if let v = ext[k] {
                        var s = "\(v)"
                        if let dict = v as? [String: Any] { s = "atoms: " + dict.keys.sorted().joined(separator: ",") }
                        print("     \(k) = \(s)")
                    }
                }
            }
        }
        // first samples
        if let reader = try? AVAssetReader(asset: asset) {
            let out = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            out.alwaysCopiesSampleData = false
            if reader.canAdd(out) {
                reader.add(out)
                if reader.startReading() {
                    var n = 0
                    var nonSync = 0
                    var firstSync: String = "?"
                    var total = 0
                    while let sb = out.copyNextSampleBuffer() {
                        total += 1
                        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
                        let dts = CMSampleBufferGetDecodeTimeStamp(sb)
                        let dur = CMSampleBufferGetDuration(sb)
                        var sync = true
                        if let att = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[String: Any]], let a = att.first {
                            if let ns = a[kCMSampleAttachmentKey_NotSync as String] as? Bool, ns { sync = false }
                            if a[kCMSampleAttachmentKey_DependsOnOthers as String] != nil && n < 3 { }
                        }
                        if total == 1 { firstSync = "\(sync)" }
                        if !sync { nonSync += 1 }
                        if n < 4 {
                            print("   sample \(total): pts \(t(pts)) dts \(dts.isValid ? t(dts) : "-") dur \(t(dur)) sync=\(sync) bytes \(CMSampleBufferGetTotalSampleSize(sb))")
                        }
                        n += 1
                    }
                    print("   samples total \(total) firstSync=\(firstSync) nonSync=\(nonSync) readerStatus \(reader.status.rawValue) err \(String(describing: reader.error))")
                } else {
                    print("   reader failed to start: \(String(describing: reader.error))")
                }
            }
        }
    }
}
