//
//  PPG.swift
//  iPPG
//
//  Created by Jessie on 7/14/22.
//

import Foundation
//import Accelerate

// data
var ppgTimestamps: [UInt] = []
var ppgValues: [Double] = []
var filteredPPG: [Double] = []
var signals: [Double] = []

// parameters for the algorithm
let lag = 20
let threshold = 3.0
let influence = 0.2

// helper to trace the peak
var peaks :[(index: Int, peak: Double)] = []
var start: Int = -1
var end: Int = -1

//features
var lastBeat: UInt = 0
var bpmList: [Double] = []
var crestList: [Double] = []
var crestTimeList: [Double] = []
var AIList: [Double] = []
var IPAList: [Double] = []

var bpm: Int = 0
var crest: Double = 0
var crestTime: Double = 0
var AI: Double = 0
var IPA: Double = 0


func clearData(s: Int, e: Int){
    
    shrinkData(s: s, e: e)
    peaks.removeAll()
    start = -1
    end = -1
    
    lastBeat = 0
    bpmList.removeAll()
    crestList.removeAll()
    crestTimeList.removeAll()
    AIList.removeAll()
    IPAList.removeAll()

    bpm = 0
    crest = 0
    crestTime = 0
    AI = 0
    IPA = 0
}

func shrinkData(s: Int, e: Int){
    
    ppgTimestamps = subArray(array: ppgTimestamps, s: s, e: e)
    ppgValues = subArray(array: ppgValues, s: s, e: e)
    signals = subArray(array: signals, s: s, e: e)
    filteredPPG = subArray(array: filteredPPG, s: s, e: e)
    start = -1
    end = -1
}

// add data and return features
func processPPG(ts: UInt, data: Double){
  
    //purge data
    if ppgTimestamps.count > lag && ppgTimestamps[ppgTimestamps.count-1] &- ppgTimestamps[0] > 2400{
        
        // keep a length of lag
        clearData(s: ppgTimestamps.count - lag, e: ppgTimestamps.count)
    }
    
    // add to list
    ppgTimestamps.append(ts)
    ppgValues.append(data)
    signals.append(detectSignal())
    
    // process signal
    if signals.count > 1{
        
        let (left, right) = processSignal()
        
        if left > 0 {
            
            //print("left=\(ppgTimestamps[left]), right=\(ppgTimestamps[right]), delta=\(right-left)\n")
            
            //feature calculation
            ppgFeature(left: left, right: right)
            
            //purge ppgTimestamps, ppgValues, filteredPPG, singals
            let purgeInex = left - 20
            shrinkData(s: purgeInex, e: ppgTimestamps.count)
        
            //update peaks
            for n in 0..<peaks.count{
                peaks[n].index = peaks[n].index - purgeInex
            }
        }
    }

}

//return peak strength, -1.0 if not a peak
func detectSignal()->Double{
    
    var singal: Double = -1.0
    let index = ppgValues.count - 1
    let ppg = ppgValues[index]
    
    if (index < lag){
        
        filteredPPG.append(ppg)
        
    }else{
        
        // avg and std is from preivous filtered data (data number = lag)
        let avgPPG = arithmeticMean(array: subArray(array: filteredPPG, s: index-lag, e: index))
        let stdPPG = standardDeviation(array: subArray(array: filteredPPG, s: index-lag, e: index))
        
        let diff = abs(ppg - avgPPG)
        
        if diff > threshold * stdPPG {
            
            if ppg > avgPPG {
                
                singal = diff  // Positive signal
            }
            
            filteredPPG.append(influence*ppg + (1-influence)*filteredPPG[filteredPPG.count-1])
            
        } else {

                filteredPPG.append(ppg)
        }
    }
    
    return singal
   
}

//return ppg wave segment, left and right index
func processSignal()->(left:Int, right:Int){
    
    let index = signals.count - 1
    let lastSignal = signals[index - 1]
    let currSignal = signals[index]
    
    // rising edge
    if lastSignal < 0 && currSignal > 0 {
     
        start = ppgValues.count - 1
    }
    
    // find falling edge
    if lastSignal > 0 && currSignal < 0 {
        
        end = ppgValues.count - 2
    }
    
    // filter small spikes
    if start > 0 && end > 0 && (end - start) > 3{
        
        let (index, peak) = indexOfMax(array: ppgValues, start: start, end: end)
        peaks.append((index: index, peak:peak))
        start = -1
        end = -1
    }
    
    // we have 2 peaks already
    if peaks.count == 2 {
        
        let left = peaks[0].index
        let right = peaks[1].index
        
        var ratio = signals[right]/signals[left]
        
        if ratio < 1{
            ratio = 1.0/ratio
        }
      
        //max 250bpm: 0.24s/beat
        if ppgTimestamps[right] &- ppgTimestamps[left] > 240 && ratio < 2.0 {
            
            peaks.remove(at: 0)
            
            //valid wave: min 40bpm 1.5s/beat
            if ppgTimestamps[right] &- ppgTimestamps[left] < 1500{
            
                return (left: left, right: right)
            }
            
        }else{// peak too close,
            
            if peaks[0].peak < peaks[1].peak{
                
                peaks.remove(at: 0)
                
            }else{
                peaks.remove(at: 1)
                
            }
        }
    }
    
    return (left: -1, right: -1)
}

// calculate feature
func ppgFeature(left: Int, right: Int){
    
    var ppg = subArray(array: ppgValues, s: left, e: right+1)
    let ts = subArray(array: ppgTimestamps, s: left, e: right+1)
    
    var derivative: [Double] = []
    var derivativeFiltered: [Double] = []
    var firstPeakFlag: Int = 0
    var firstPeak: Int = 0
    var secondPeakFlag: Int = 0
    var secondPeak: Int = 0
    var notch: Int = 0
    var systolic: Double = 0
    var diastolic: Double = 0
    var negative : Double = 0
    
    //flip
    for n in 0..<ppg.count{
        ppg[n] = 1000.0 - ppg[n]
    }
    
    for n in 0..<ppg.count-1{
        derivative.append(ppg[n+1] - ppg[n])
    }
    
    for n in 1..<derivative.count-1{
        derivativeFiltered.append(derivative[n-1]*0.2 + derivative[n]*0.4 + derivative[n+1]*0.2)
    }
    
    //First peak:  cross from positive to negative, and overshoot more than 20
    //notch: after first peak, cross from negative to positive
    //Second peak: cross from positive to negative, and overshoot more than 20
    //plus one to compensate filtering lag
    for n in 1..<derivativeFiltered.count{
        
        if firstPeak == 0{
            
            // first peak is in the first half
            if n > derivativeFiltered.count/2{
                break
            }
            
            if firstPeakFlag == 0 && derivativeFiltered[n-1] > 0 && derivativeFiltered[n] <= 0{
                firstPeakFlag = n
            }
            
            if firstPeakFlag > 0 && derivativeFiltered[n] > 0{
                
                firstPeakFlag = 0
            }
            
            if firstPeakFlag > 0 && derivativeFiltered[n] <= 0 {
                
                negative += derivativeFiltered[n]
                
            }
            
            if firstPeakFlag > 0 && negative <= -20{
                
                firstPeak = firstPeakFlag + 1
                
                // reset
                negative = 0
            }
            
        }else{
            
            if notch == 0{
                
                if derivativeFiltered[n-1] < 0 && derivativeFiltered[n] >= 0{
                    
                    notch = n + 1
                }
                
            }else{
                
                if secondPeakFlag == 0 && derivativeFiltered[n-1] > 0 && derivativeFiltered[n] <= 0{
                    secondPeakFlag = n
                }
                
                if secondPeakFlag > 0 && derivativeFiltered[n] > 0{
                    
                    secondPeakFlag = 0
                }
                
                if secondPeakFlag > 0 && derivativeFiltered[n] <= 0 {
                    
                    negative += derivativeFiltered[n]
                }
                
                if secondPeakFlag > 0 && negative <= -20{
                    
                    secondPeak = secondPeakFlag + 1
                    //print("found all: left=\(ppgTimestamps[left]), right=\(ppgTimestamps[right]), delta=\(right-left), first=\(firstPeak), notch=\(notch), second=\(secondPeak)")
                    break
                }
            }
        }
    }
    
    if firstPeak == 0{

        (firstPeak, systolic) = indexOfMax(array: ppg, start: 0, end: (ppg.count-1)/2)
        (secondPeak, diastolic) = indexOfMax(array: ppg, start: (ppg.count-1)/2 + 1, end: ppg.count-1)
        notch = (firstPeak + secondPeak)/2
        //print("first peak missing: left=\(ppgTimestamps[left]), right=\(ppgTimestamps[right]), delta=\(right-left)")
        
    }else{
        
        if notch == 0{
            notch = ppg.count * 2 / 3
            secondPeak = (notch + ppg.count - 1)/2
            //print("notch missing: left=\(ppgTimestamps[left]), right=\(ppgTimestamps[right]), delta=\(right-left)")
        }
        
        //not likly happen
        if secondPeak == 0{
            secondPeak = ppg.count - 1
            //print("second peak missing: left=\(ppgTimestamps[left]), right=\(ppgTimestamps[right]), delta=\(right-left)")
        }
    }
    
    systolic = ppg[firstPeak]
    diastolic = ppg[secondPeak]
    AIList.append(100*(systolic-diastolic)/systolic)
    
    var a1: Double = 0
    var a2: Double = 0
    
    for n in 1...notch{
        a1 += (ppg[n-1] + ppg[n]) * Double(ts[n] &- ts[n-1]) / 2
    }
    
    for n in notch+1..<ppg.count{
        a2 += (ppg[n-1] + ppg[n]) * Double(ts[n] &- ts[n-1]) / 2
    }
    
    IPAList.append(a2/a1)
    
    crestList.append(systolic - ppg[0])
    crestTimeList.append(Double(ts[firstPeak] &- ts[0])/1000.0)
    
    let beat  = 60000.0/Double(ppgTimestamps[right] &- ppgTimestamps[left])
    bpmList.append(beat)
    
    // average: circular buffer maybe a better way
    if bpmList.count >= 5{
        
        var sum = bpmList.reduce(0,+)
        bpm = Int(sum/Double(bpmList.count) + 0.5)
        
        sum = crestList.reduce(0,+)
        crest = sum/Double(crestList.count)
        
        sum = crestTimeList.reduce(0,+)
        crestTime = sum/Double(crestTimeList.count)
        
        sum = AIList.reduce(0,+)
        AI = sum/Double(AIList.count)
        
        sum = IPAList.reduce(0,+)
        IPA = sum/Double(IPAList.count)
    }
    
    if bpmList.count >= 10{
        
        bpmList.remove(at: 0)
        crestList.remove(at: 0)
        crestTimeList.remove(at: 0)
        AIList.remove(at: 0)
        IPAList.remove(at: 0)
    }
        
}
    
    
    


