//
//  Debug.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation

class Debug
{
    public var enabled = false
        
    internal init(enabled: Bool)
    {
        self.enabled = enabled
    }
        
    public func log(_ message: String)
    {
        if enabled
        {
            print(message)
        }
    }
}
