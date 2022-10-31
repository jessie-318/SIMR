//
//  Helper.swift
//  iPPG
//
//  Created by Jessie on 7/14/22.
//

import Foundation

// Function to calculate the arithmetic mean
func arithmeticMean(array: [Double]) -> Double {
    var total: Double = 0
    for number in array {
        total += number
    }
    return total / Double(array.count)
}

// Function to calculate the standard deviation
func standardDeviation(array: [Double]) -> Double
{
    let length = Double(array.count)
    let avg = array.reduce(0, {$0 + $1}) / length
    let sumOfSquaredAvgDiff = array.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
    return sqrt(sumOfSquaredAvgDiff / length)
}

// Function to extract some range from an array
func subArray<T>(array: [T], s: Int, e: Int) -> [T] {
    if e > array.count {
        return []
    }
    return Array(array[s..<min(e, array.count)])
}

func indexOfMax(array: [Double], start: Int, end: Int)->(index: Int, peak: Double){
    
    var index: Int = start
    var maxValue: Double = array[start]
    
    for i in start+1...end{
        
        if array[i] > maxValue{
            index = i
            maxValue = array[i]
        }
    }
    
    return (index: index, peak: maxValue)
}


