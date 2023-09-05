//
//  StateMachine.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation

enum ChronosState
{
    case idle
    case potential
    case sync
}

protocol StateMachineDelegate
{
    func didWitnessStateTransition(state: ChronosState, identifier: Int, timestamp: Int)
}

class SyncStateMachine
{
    public var delegate : StateMachineDelegate?
        
    private var state      = ChronosState.idle
    private var identifier = -1
    private var timestamp  = -1
        
    internal init() {}
    
    deinit {}
        
    public func stop()
    {
        state      = .idle
        identifier = -1
        timestamp  = -1
    }
    
    public func tick(identifier: Int, timestamp: Int)
    {
        let distinctIdentifier = identifier != self.identifier
        let distinctTimestamp = timestamp != self.timestamp
        let previousTimestamp = timestamp < self.timestamp
        
        switch state
        {
            case .idle:
                if distinctIdentifier
                {
                    self.identifier = identifier
                    self.timestamp = timestamp
                    self.state = .potential
                    delegate?.didWitnessStateTransition(state: .potential, identifier: identifier, timestamp: timestamp)
                }
                break
                
            case .potential:
                if distinctIdentifier
                {
                    reset()
                }
                else
                {
                    if previousTimestamp
                    {
                        reset()
                    }
                    else if distinctTimestamp
                    {
                        self.timestamp = timestamp
                        self.state = .sync
                        delegate?.didWitnessStateTransition(state: .sync, identifier: identifier, timestamp: timestamp)
                    }
                }
                break
                
            case .sync:
                if distinctIdentifier
                {
                    reset()
                }
                else
                {
                    if previousTimestamp
                    {
                        reset()
                    }
                    else if distinctTimestamp
                    {
                        self.timestamp = timestamp
                        delegate?.didWitnessStateTransition(state: .sync, identifier: identifier, timestamp: timestamp)
                    }
                }
                break
        }
    }
        
    private func reset()
    {
        identifier = -1
        timestamp  = -1
        state      = .idle
        delegate?.didWitnessStateTransition(state: .idle, identifier: -1, timestamp: -1)
    }
}
