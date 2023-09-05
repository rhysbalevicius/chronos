//
//  Chronos.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation

public protocol ChronosDelegate
{
    func hasObservedSyncTransition(_ hasSynchronized: Bool)
    func hasObservedIdentifier(_ identifier: Int)
    func hasObservedTimestamp(_ timestamp: Double)
}

public class Chronos
{
    // MARK: - Public properties
    
    public var delegate : ChronosDelegate?
    public var enableDebug = false {
        didSet { debug(enableDebug) }
    }
    
    // MARK: - Private properties
    
    private var audioCapture  : AudioCapture!
    private var demodulator   : Demodulator!
    private var stateMachine  : SyncStateMachine!
    private var internalTimer : InternalTimer!
    private let debug = Debug(enabled: false)
    
    // MARK: - Lifecycle
    
    public init()
    {
        audioCapture  = AudioCapture(audioInputCallback: audioInputCallback)
        stateMachine  = SyncStateMachine()
        internalTimer = InternalTimer()
        demodulator   = Demodulator()
        
        demodulator.delegate   = self
        stateMachine.delegate  = self
        internalTimer.delegate = self
    }
    
    deinit
    {
        audioCapture = nil
        demodulator  = nil
        stateMachine = nil
    }
    
    // MARK: - Public methods
    
    public func start()
    {
        debug.log("[Chronos] Starting...")
        
        requestMicrophonePermission { granted in
            if granted
            {
                self.audioCapture.initialize()
                self.audioCapture.start()
                self.debug.log("[Chronos] Started successfully.")
            }
            else
            {
                self.debug.log("[Chronos] Failed to start. Microphone access not permitted.")
            }
        }
    }
    
    public func reset()
    {
        internalTimer.stop()
        stateMachine.stop()
        debug.log("[Chronos] Resetting...")
    }
    
    public func stop()
    {
        debug.log("[Chronos] Stopping...")
        audioCapture.stop()
        debug.log("[Chronos] Stopped successfully.")
    }
    
    public func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void)
    {
        debug.log("[Chronos] Requesting microphone access.")
        
        audioCapture.requestPermission { granted in
            self.debug.log("[Chronos] Microphone access permitted: \(granted)")
            completion(granted)
        }
    }
    
    // MARK: - Private methods
    
    private func audioInputCallback(numberOfFrames: Int, samples: Optional<UnsafeMutablePointer<Int8>>)
    {
        var monoSamples = [Int8]()
        monoSamples.append(contentsOf: UnsafeBufferPointer(start: samples, count: numberOfFrames))
        demodulator.consumeSamples(monoSamples, numberOfFrames)
    }
    
    private func debug(_ enabled: Bool)
    {
        debug.enabled             = enabled
        audioCapture.enableDebug  = enabled
        demodulator.enableDebug   = enabled
    }
}

// MARK: - Delegates

extension Chronos : DemodulatorDelegate
{
    func didDecodePayload(identifier: Int, timestamp: Int)
    {
        stateMachine.tick(identifier: identifier, timestamp: timestamp)
    }
}

extension Chronos : StateMachineDelegate
{
    func didWitnessStateTransition(state: ChronosState, identifier: Int, timestamp: Int)
    {
        switch state {
            case .idle:
                debug.log("[Chronos] Entered idle state.")
                delegate?.hasObservedSyncTransition(false)
                internalTimer.stop()
                break
                
            case .potential:
                debug.log("[Chronos] Entered potential sync state.")
                delegate?.hasObservedIdentifier(identifier)
                internalTimer.start(withTimestamp: timestamp)
                break
                
            case .sync:
                debug.log("[Chronos] Entered sync state.")
                delegate?.hasObservedSyncTransition(true)
                break
        }
    }
}

extension Chronos : InternalTimerDelegate
{
    func didReceiveTimestamp(_ timestamp: Double)
    {
        delegate?.hasObservedTimestamp(timestamp)
    }
}
