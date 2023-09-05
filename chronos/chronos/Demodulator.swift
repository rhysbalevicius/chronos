//
//  Demodulator.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation
import Accelerate
import Chronos_Private

protocol DemodulatorDelegate
{
    func didDecodePayload(identifier: Int, timestamp: Int)
}

class Demodulator
{
    public var delegate : DemodulatorDelegate?
    public var enableDebug = false {
        didSet { debug.enabled = enableDebug }
    }
        
    private var spectrumId       = 0
    private var payloadLength    = 4
    private var payloadFrames    = 9
    private var payloadFrameSize = 3
    private var frequencyStart   = 350
    private var samplesPerFrame  = 1024
    private var samplesNeeded    = 1024
    private var transformInput   = Array<Float>(repeating: 0, count: 2048)
    private var transformOutput  = Array<Float>(repeating: 0, count: 2048)
    private var sampleSpectrum   = Array<Float>(repeating: 0, count: 2048)
    private var sampleAmplitude  = Array<Float>(repeating: 0, count: 2176)
    private let sampleSize       = MemoryLayout<Int8>.size
    private var sampleBuffer     = Array<Int8>(repeating: 0, count: 16384 * MemoryLayout<Int8>.size)
    private var spectrum         = Array<Array<Float>>(repeating: Array<Float>(repeating: 0, count: 2048), count: 36)
    private var payload          : Array<Int8>
    private let debug            = Debug(enabled: false)
    private let decoder          = Chronos_Private.Decoder()
    
    internal init()
    {
        payload = Array<Int8>(repeating: 0, count: payloadLength)
    }
    
    deinit {}
        
    func consumeSamples(_ dataBuffer: Array<Int8>, _ dataSize: Int)
    {
        var bufferOffset = 0
        var bufferSize   = dataSize

        while true
        {
            let bytesNeeded   = samplesNeeded * sampleSize
            var bytesRecorded = 0
            let sampleOffset  = samplesPerFrame - samplesNeeded
            let bytesCopied   = min(bufferSize, bytesNeeded)
            
            dataBuffer.copy(a: &sampleBuffer, offsetA: sampleOffset, offsetB: bufferOffset, count: bytesCopied)
            
            bytesRecorded = bytesCopied
            bufferSize   -= bytesCopied
            bufferOffset += bytesCopied
            
            if bytesRecorded % sampleSize != 0 || bytesRecorded > bytesNeeded
            {
                samplesNeeded = samplesPerFrame
            }

            let samplesRecorded = bytesRecorded / sampleSize
            if samplesRecorded == 0
            {
                break
            }

            for i in 0 ..< samplesRecorded
            {
                sampleAmplitude[sampleOffset + i] = Float(sampleBuffer[i]) / 128
            }
            
            if samplesRecorded >= samplesPerFrame
            {
                analyzeSamples()
                
                let samplesRemaining = samplesRecorded - samplesPerFrame
                for i in 0 ..< samplesRemaining
                {
                    sampleAmplitude[i] = sampleAmplitude[samplesPerFrame + i]
                }
                
                samplesNeeded = samplesPerFrame - samplesRemaining
            }
            else
            {
                samplesNeeded = samplesPerFrame - samplesRecorded
                break
            }
        }
    }
    
    private func fastFourierTransform(_ buffer: Array<Float>, _ bufferSize: Int) -> Array<Float>
    {
        var signal = Array<Float>()
        
        for i in 0 ..< bufferSize
        {
            signal.append(buffer[i])
            signal.append(0)
        }
        
        let elementCount = signal.count
        let complexValuesCount = elementCount/2
        
        var signalReal = Array<Float>(repeating: 0, count: complexValuesCount)
        var signalImag = Array<Float>(repeating: 0, count: complexValuesCount)
        
        signal.withUnsafeBytes { signalPtr in
            signalReal.withUnsafeMutableBufferPointer { signalRealPtr in
                signalImag.withUnsafeMutableBufferPointer { signalImagPtr in
                    var splitComplex = DSPSplitComplex(realp: signalRealPtr.baseAddress!, imagp: signalImagPtr.baseAddress!)
                    
                    vDSP_ctoz(Array<DSPComplex>(signalPtr.bindMemory(to: DSPComplex.self)), 2, &splitComplex, 1, vDSP_Length(complexValuesCount))
                }
            }
        }
        
        let dft = try? vDSP.DiscreteFourierTransform(
            count: complexValuesCount,
                           direction: .forward,
                           transformType: .complexComplex,
                           ofType: Float.self
        )

        var fftOutputReal = Array<Float>(repeating: 0, count: complexValuesCount)
        var fftOutputImag = Array<Float>(repeating: 0, count: complexValuesCount)

        dft?.transform(inputReal: signalReal, inputImaginary: signalImag, outputReal: &fftOutputReal, outputImaginary: &fftOutputImag)

        var fftOutputInterleaved = Array<Float>(repeating: 0, count: elementCount)

        fftOutputReal.withUnsafeMutableBufferPointer { fftOutputRealPtr in
            fftOutputImag.withUnsafeMutableBufferPointer { fftOutputImagPtr in
                var splitComplex = DSPSplitComplex(realp: fftOutputRealPtr.baseAddress!,
                                                   imagp: fftOutputImagPtr.baseAddress!)
                
                fftOutputInterleaved.withUnsafeMutableBytes { windowPtr in
                    vDSP_ztoc(&splitComplex, 1,
                              windowPtr.bindMemory(to: DSPComplex.self).baseAddress!, 2,
                              vDSP_Length(complexValuesCount))
                }
            }
        }

        return fftOutputInterleaved
    }
    
    private func analyzeSamples()
    {
        samplesNeeded = samplesPerFrame
        transformOutput = fastFourierTransform(sampleAmplitude, samplesPerFrame)

        for i in 0 ..< samplesPerFrame
        {
            sampleSpectrum[i] = pow(transformOutput[2*i], 2) + pow(transformOutput[2*i + 1], 2)
        }

        for i in 1 ..< samplesPerFrame / 2
        {
            sampleSpectrum[i] += sampleSpectrum[samplesPerFrame - i]
        }
        
        spectrum[spectrumId] = sampleSpectrum
        spectrumId += 1
        
        if spectrumId >= spectrum.count
        {
            spectrumId = 0
        }

        let encodedLength = payloadLength + 4
        let chunkLength   = (encodedLength + payloadFrameSize - 1) / payloadFrameSize
        var startId       = spectrumId - chunkLength * payloadFrames
        
        if startId < 0
        {
            startId += spectrum.count
        }

        var detectedTotal  = 0
        var neededTotal    = 0
        var hasDetected    = true
        var detectedSignal = Array<Int8>(repeating: 0, count: 2 * encodedLength)
        var toneRange      = Array<Array<Int>>(repeating: [], count: 2 * payloadFrameSize)
        
        for i in 0 ..< chunkLength
        {
            for j in 0 ..< toneRange.count
            {
                toneRange[j] = Array(repeating: 0, count: 16)
            }
            
            for j in 0 ..< payloadFrames
            {
                let time = (startId + i * payloadFrames + j) % spectrum.count
                for k in 0 ..< payloadFrameSize
                {
                    var lo = -1
                    var hi = -1
                    var loMax : Float = 0.0
                    var hiMax : Float = 0.0
                    
                    for bit in 0 ..< 16
                    {
                        let hz = frequencyStart + 32 * k + bit
                        if loMax <= spectrum[time][hz]
                        {
                            loMax = spectrum[time][hz]
                            lo = bit
                        }

                        if hiMax <= spectrum[time][hz + 16]
                        {
                            hiMax = spectrum[time][hz + 16]
                            hi = bit
                        }
                    }
                    
                    toneRange[2 * k][lo] += 1
                    toneRange[2 * k + 1][hi] += 1
                }
            }

            var bitsNeeded   = 0
            var detectedBits = 0
            
            for j in 0 ..< payloadFrameSize
            {
                if i * payloadFrameSize + j >= encodedLength
                {
                    break
                }
                
                bitsNeeded += 2
                
                for bit in 0 ..< 16
                {
                    if toneRange[2 * j][bit] > payloadFrames / 2
                    {
                        detectedSignal[2 * (i * payloadFrameSize + j)] = Int8(bit)
                        detectedBits += 1
                    }
                    
                    if toneRange[2 * j + 1][bit] > payloadFrames / 2
                    {
                        detectedSignal[2 * (i * payloadFrameSize + j) + 1] = Int8(bit)
                        detectedBits += 1
                    }
                }
            }

            neededTotal   += bitsNeeded
            detectedTotal += detectedBits
        }
        
        if 4 * detectedTotal < 3 * neededTotal
        {
            hasDetected = false
        }
        
        if hasDetected
        {
            let result = decoder.decode(
                encodedLength,
                forDetected: &detectedSignal,
                asOutput: &payload
            )
            if result != 0
            {
                let (identifier, timestamp) = decodePayload(payload, payloadLength / 2)
                delegate?.didDecodePayload(identifier: identifier, timestamp: timestamp)
            }
        }
    }
    
    private func decodePayload(_ payload: Array<Int8>, _ length: Int) -> (Int, Int)
    {
        let chunked    = payload.map { Int($0) }.chunked(into: length)
        let identifier = decodePayloadChunk(chunked[0], length)
        let timestamp  = decodePayloadChunk(chunked[1], length)

        return (identifier, timestamp)
    }
    
    private func decodePayloadChunk(_ payload: Array<Int>, _ length: Int) -> Int
    {
        var result = 0
        
        for i in 0 ..< length
        {
            result += ((payload[i] + 256) % 256) << (8 * i)
        }
        
        return result
    }
}
