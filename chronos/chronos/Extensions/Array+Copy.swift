//
//  Array+Copy.swift
//  chronos
//
//  Created by Rhys Balevicius.
//

import Foundation

extension Array where Element == Float
{
    func copy(a: inout Array<Float>, offsetA: Int = 0, offsetB: Int = 0, count: Int? = nil)
    {
        let max = count ?? self.endIndex - self.startIndex - offsetB
        for i in 0 ..< max
        {
            let indA = offsetA + i
            let indB = offsetB + i
            a[indA] = self[indB]
        }
    }
}

extension Array where Element == Int8 {
    func copy(a: inout Array<Int8>, offsetA: Int = 0, offsetB: Int = 0, count: Int? = nil)
    {
        let max = count ?? self.endIndex - self.startIndex - offsetB

        for i in 0..<max
        {
            let indA = offsetA + i
            let indB = offsetB + i

            a[indA] = self[indB]
        }
    }
}
