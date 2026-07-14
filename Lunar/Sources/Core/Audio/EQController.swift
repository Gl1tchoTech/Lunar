import Foundation
import AVFoundation

/// Bridges a flat `[Float]` band array (as persisted on `EQPreset.bands`)
/// to a real `AVAudioUnitEQ` instance.
///
/// ISO standard band centers used by every commercial music player:
/// `[32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]` Hz.
enum EQController {

    /// Brand-new EQ with all bands configured but at 0 dB gain and
    /// `.bypass = true` (no audible colouration out of the box).
    static func makeUnit() -> AVAudioUnitEQ {
        let eq = AVAudioUnitEQ(numberOfBands: 10)
        let centers = isoBandCentersHz
        for (index, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Float(centers[index])
            band.bandwidth = 1.0     // octave
            band.gain = 0
            band.bypass = true       // neutral until user engages
        }
        return eq
    }

    /// Apply a band array onto an existing unit. Out-of-range gains
    /// are clamped to `[-12, +12]`. A zero-equal array engages all
    /// bands (`bypass = false`) so the user can hear flat response
    /// (engineers use this for "A/B test" before tweaking).
    static func apply(bands: [Float], to unit: AVAudioUnitEQ) {
        let clamped = bands.map { min(12.0, max(-12.0, $0)) }
        for (index, band) in unit.bands.enumerated() where index < clamped.count {
            band.gain = clamped[index]
            band.bypass = false
        }
    }

    /// Disable all bands (audio passes through untouched).
    static func bypass(_ unit: AVAudioUnitEQ) {
        for band in unit.bands { band.bypass = true }
    }

    /// ISO band centers, in Hz, for the 10 bands.
    static let isoBandCentersHz: [Double] = [
        32, 64, 128, 256, 512,
        1_024, 2_048, 4_096, 8_192, 16_384
    ]
}
