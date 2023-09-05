//
//  InternalTimer.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation
import QuartzCore

protocol InternalTimerDelegate
{
    func didReceiveTimestamp(_ timestamp: Double)
}

class InternalTimer
{
    public var delegate : InternalTimerDelegate?
        
    private var currentTime : Double = 0.0
    private var startedTime : Double = 0.0
    private var timer       : CADisplayLink!
        
    internal init()
    {
        timer = CADisplayLink(target: self, selector: #selector(tick))
        timer.preferredFramesPerSecond = 30
        timer.add(to: .current, forMode: .common)
        timer.isPaused = true
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
        
    public func start(withTimestamp: Int = 0)
    {
        currentTime = Double(withTimestamp) / 1000
        startedTime = CACurrentMediaTime()
        timer.isPaused = false
    }
    
    public func stop()
    {
        timer.isPaused = true
        currentTime = 0.0
        startedTime = 0.0
    }
            
    @objc private func tick()
    {
        delegate?.didReceiveTimestamp(currentTime + CACurrentMediaTime() - startedTime)
    }
}
