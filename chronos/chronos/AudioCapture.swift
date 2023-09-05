//
//  AudioCapture.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import AVFoundation

typealias MicrophoneInputCallback = (
    _ numberOfFrames : Int,
    _ samples        : UnsafeMutablePointer<Int8>?
    
) -> Void

class AudioCapture
{
    // MARK: - Public properties
    
    public var enableDebug = false {
        didSet { debug.enabled = enableDebug }
    }
    
    // MARK: - Private properties
    
    private let audioSession       : AVAudioSession = AVAudioSession.sharedInstance()
    private var audioUnit          : AudioUnit!
    private var sampleRate         : Float
    private var numberOfChannels   : Int
    private var audioInputCallback : MicrophoneInputCallback!
    
    private var shouldPerformDCOffsetRejection = false
    private let outputBus : UInt32 = 0
    private let inputBus  : UInt32 = 1
    private let debug = Debug(enabled: false)

    // MARK: - Lifecycle
    
    internal init(audioInputCallback: @escaping MicrophoneInputCallback, sampleRate: Float = 48000.0, numberOfChannels: Int = 1)
    {
        self.sampleRate         = sampleRate
        self.numberOfChannels   = numberOfChannels
        self.audioInputCallback = audioInputCallback
    }
    
    deinit
    {
        stop()
        audioUnit = nil
    }

    // MARK: - Public methods
    
    public func requestPermission(_ callback: @escaping (Bool) -> Void)
    {
        audioSession.requestRecordPermission { (granted) -> Void in
            callback(granted)
        }
    }

    public func initialize()
    {
        initializeAudioSession()
        initializeAudioUnit()
    }

    public func start()
    {
        guard audioUnit != nil else
        {
            debug.log("[Chronos] Capture start failed. AudioUnit is nil.")
            return
        }
        
        do
        {
            try audioSession.setActive(true)
            
            let audioUnitInitStatus : OSStatus = AudioUnitInitialize(audioUnit)
            let audioUnitOutputStatus : OSStatus = AudioOutputUnitStart(audioUnit)
            assert(audioUnitInitStatus == noErr, "[Chronos] Capture start failed. AudioUnit initialization failed: \(audioUnitInitStatus.description)")
            assert(audioUnitOutputStatus == noErr, "[Chronos] Capture start failed. AudioUnit output start failed: \(audioUnitOutputStatus.description)")

        }
        catch
        {
            debug.log("[Chronos] Capture start failed: \(error)")
        }
    }

    public func stop()
    {
        do
        {
            let audioUnitStatus : OSStatus = AudioUnitUninitialize(audioUnit)
            assert(audioUnitStatus == noErr, "[Chronos] Capture stop failed. AudioUnit deinitialization error: \(audioUnitStatus)")
            
            try audioSession.setActive(false)
        }
        catch
        {
            debug.log("[Chronos] Capture stop failed: \(error)")
        }
    }

    // MARK: - Private methods
    
    private func initializeAudioSession()
    {
        guard audioSession.availableCategories.contains(.record) else
        {
            debug.log("[Chronos] Capture initialization failed. Microphone access not permitted.")
            return
        }
        
        do
        {
            try audioSession.setCategory(.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setPreferredSampleRate(Double(sampleRate))
        }
        catch
        {
            debug.log("[Chronos] Capture initialization failed. \(error).")
        }
    }
    
    private func initializeAudioUnit()
    {
        var componentDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        var osStatus : OSStatus = noErr

        // Get an audio component matching the specified description
        let component : AudioComponent! = AudioComponentFindNext(nil, &componentDescription)
        assert(component != nil, "[Chronos] Capture initialization failed. Couldn't find a default audio component.")

        // Create an instance of the AudioUnit
        var temporaryAudioUnit : AudioUnit?
        osStatus = AudioComponentInstanceNew(component, &temporaryAudioUnit)
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. AudioComponentInstanceNew error: \(osStatus.description)")
        self.audioUnit = temporaryAudioUnit

        // Enable I/O for audio stream
        var inData : UInt32 = 1

        osStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            inputBus,
            &inData,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Enable input error: \(osStatus.description)")

        osStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            outputBus,
            &inData,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Enable output error: \(osStatus.description)")

        // Set format to linear PCM
        var streamFormatDescription = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
            mBytesPerPacket: UInt32(MemoryLayout<Int8>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Int8>.size),
            mChannelsPerFrame: UInt32(numberOfChannels),
            mBitsPerChannel: UInt32(MemoryLayout<Int8>.size) * 8,
            mReserved: 0)

        // Set format for input and output buses
        osStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            outputBus,
            &streamFormatDescription,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Output bus error: \(osStatus.description)")

        osStatus = AudioUnitSetProperty(
            self.audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            self.inputBus,
            &streamFormatDescription,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Input bus error: \(osStatus.description)")

        // Setup our callback function
        var inputCallbackStruct = AURenderCallbackStruct(
            inputProc: AudioCapture.renderCallback,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        osStatus = AudioUnitSetProperty(
            audioUnit,
            AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
            AudioUnitScope(kAudioUnitScope_Global),
            inputBus,
            &inputCallbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Callback error: \(osStatus.description)")

        // Ask CoreAudio to allocate buffers for us on render
        osStatus = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
            AudioUnitScope(kAudioUnitScope_Output),
            inputBus,
            &inData,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osStatus == noErr, "[Chronos] Capture initialization failed. Allocation error: \(osStatus.description)")
    }
    
    // MARK: - Static methods
    
    private static let renderCallback : AURenderCallback = { (inRefCon, ioActionFlags, inTimestamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in

        let audioInput = unsafeBitCast(inRefCon, to: AudioCapture.self)
        var osStatus = noErr

        // mData can be set to nil since CoreAudio will allocate buffers for us, so it will be populated in each render
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(audioInput.numberOfChannels),
                mDataByteSize: 4,
                mData: nil))

        osStatus = AudioUnitRender(
            audioInput.audioUnit,
            ioActionFlags,
            inTimestamp,
            inBusNumber,
            inNumberFrames,
            &bufferList)
        assert(osStatus == noErr, "[Chronos] Capture renderer failed: \(osStatus.description)")
        
        if let mData = bufferList.mBuffers.mData
        {
            audioInput.audioInputCallback(
                Int(inNumberFrames),
                mData.assumingMemoryBound(to: Int8.self)
            )
        }
        
        return 0
    }
}
