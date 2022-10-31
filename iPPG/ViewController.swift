//
//  ViewController.swift
//  iPPG
//
//  Created by Jessie on 7/9/22.
//

import UIKit
import CoreBluetooth
import SwiftChart

let ppgServiceCBUUID = CBUUID(string: "0xFFE0")
let ppgCharacteristicCBUUID = CBUUID(string: "0xFFE1")


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var metricsTableView: UITableView!
    @IBOutlet weak var ppgChartView: Chart!
    @IBOutlet weak var recordingBtn: UIButton!
    @IBOutlet weak var pauseBtn: UIButton!
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var leftover:String = ""
    var ppgSerie: [(x:Double,y:Double)] =  []
    var pastPPGSerie: [(x:Double,y:Double)] =  []
    let bufferLength: Int = 300
    var curPos: Int = 0
    var bPause: Bool = false
    var bRecording : Bool = false
    var fileHandle:FileHandle? = nil
    var recordingTimer: Timer? = nil
    var timerTick: Int = 300
    
    //var lock = NSLock()
    
    var bConnected: Bool = false {
           didSet {
               
               if bConnected{
                   
                   clearData(s: 0, e: 0)
               }
               
               pauseBtn.isEnabled = bConnected
               
               if !bRecording{
                   recordingBtn.isEnabled = bConnected
               }
           }
       }
   
    @IBAction func onPauseClick(_ sender: UIButton) {
        
        if !bPause{
            
            //stop
            bPause = true
            sender.setTitle("Resume", for: .normal)
            
            
        }else{
            
            //restart
            bPause = false
            sender.setTitle("Pause", for: .normal)
            
        }
        
    
    }
    
    func startRecording(){
        
        timerTick = 300
        let ts = getTimestamp()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(ts).csv")
        //print(url)
        try? "timestamp,value\n".write(to: url, atomically: true, encoding: String.Encoding.utf8)
        
        fileHandle = try? FileHandle(forUpdating: url)
        bRecording = true
        recordingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(recordingTimerExpired), userInfo: nil, repeats: true)
        
    }
    
    @IBAction func onRecordClick(_ sender: UIButton) {
        
        if !bRecording{
            
            let dialogMessage = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                  
                    //let titleFont = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 24)]
                    //let titleAttrString = NSMutableAttributedString(string: "PPG Recording\n", attributes: titleFont)
            
                    let messageFont = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20)]
                    let messageAttrString = NSMutableAttributedString(string: "Please place your finger on the sensor and click OK. iPPG will record PPG for 5min.", attributes: messageFont)

                    //dialogMessage.setValue(titleAttrString, forKey:"attributedTitle")
                    dialogMessage.setValue(messageAttrString, forKey:"attributedMessage")

                  // Create OK button with action handler
                  let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                       sender.setTitle("Stop (300 sec)", for: .normal)
                       self.startRecording()
                  })
                  
                  // Create Cancel button with action handlder
                  let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
                      //print("Cancel button tapped")
                  }
                  
                  //Add OK and Cancel button to dialog message
                  dialogMessage.addAction(ok)
                  dialogMessage.addAction(cancel)
                  
                  // Present dialog message to user
                  self.present(dialogMessage, animated: true, completion: nil)
            
        }else{
            
            if let fp  = fileHandle{
                fp.closeFile()
            }
            
            fileHandle = nil
            recordingTimer?.invalidate()
            recordingTimer = nil
            bRecording = false
            sender.setTitle("Record (5min)", for: .normal)
            recordingBtn.isEnabled = bConnected
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        setupChart()
        bpmLabel.text = "0"
        recordingBtn.isEnabled  = false
        pauseBtn.isEnabled = false
        
    }
    
    @objc func recordingTimerExpired() {
        
        timerTick -= 1
        
        if timerTick == 0{
            
            recordingTimer?.invalidate()
            recordingTimer = nil
            
            if let fp  = fileHandle{
                fp.closeFile()
            }
            fileHandle = nil
            bRecording = false
            recordingBtn.setTitle("Record (5min)", for: .normal)
            recordingBtn.isEnabled = bConnected
            timerTick = 300
        }else{
            
            let text = "Stop (\(timerTick) sec)"
            recordingBtn.setTitle(text, for: .normal)
        }
    
    }
    
    func getTimestamp()->String{
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = formatter.string(from: now)
        
        return dateString
    }
    
    func setupChart(){
        
        metricsTableView.delegate = self
        metricsTableView.dataSource = self
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Do any additional setup after loading the view.
        ppgChartView.backgroundColor = .systemBlue
        ppgChartView.minX = 0
        ppgChartView.maxX = 315
        ppgChartView.minY = 0
        ppgChartView.maxY = 1200
        ppgChartView.xLabels = [0.0, 50.0, 100.0, 150.0, 200.0, 250.0, 300.0]
        ppgChartView.yLabels = [200.0, 400.0, 600.0, 800.0, 1000.0]
        ppgChartView.axesColor = .white
        ppgChartView.gridColor = .white
        ppgChartView.labelColor = .white
        ppgChartView.labelFont = .boldSystemFont(ofSize: 14)
        ppgChartView.lineWidth = 3
        ppgChartView.bottomInset = 30
        
        // Create a new series specifying x and y values
        let serie1 = ChartSeries(data: ppgSerie)
        serie1.color = .white
        ppgChartView.add(serie1)
        
        let serie2 = ChartSeries(data: pastPPGSerie)
        serie2.color = .white
        ppgChartView.add(serie2)
        
    }
    
    func refreshChart(){
        
        // set serie will call setNeedsDisplay
        let serie1 = ChartSeries(data: ppgSerie)
        serie1.color = .white
        ppgChartView.series[0] = serie1
        
        let serie2 = ChartSeries(data: pastPPGSerie)
        serie2.color = .gray
        ppgChartView.series[1] = serie2
        
    }
    
    
    // how many features we calculate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    // show the feature
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
            
        switch indexPath.row{
        
        case 0:
            cell.textLabel?.text = String(format: "Crest: %.2f", crest)
            cell.textLabel?.font = .systemFont(ofSize: 24)
        case 1:
            cell.textLabel?.text = String(format: "Crest Time (sec): %.2f", crestTime)
            cell.textLabel?.font = .systemFont(ofSize: 24)
        case 2:
            cell.textLabel?.text = String(format: "AI (%%): %.2f", AI)
            cell.textLabel?.font = .systemFont(ofSize: 24)
        case 3:
            cell.textLabel?.text = String(format: "IPA: %.2f", IPA)
            cell.textLabel?.font = .systemFont(ofSize: 24)
        
        default:
            cell.textLabel?.text = ""
        
        }
        return cell
    }
    
    
    func onPPGReceived(_ ppgStr: String) {
        //heartRateLabel.text = String(heartRate)
        let trimmed = ppgStr.trimmingCharacters(in: .whitespacesAndNewlines)
        let pair = trimmed.components(separatedBy: ",")
      
        if pair.count == 2{
            
            if let ts = UInt(pair[0]), let data = Double(pair[1]){
                
                // save to file if recording
                if let fp  = fileHandle{
                    
                    let line = trimmed + "\n"
                    //print("write: \(line)")
                    
                    fp.seekToEndOfFile()
                    fp.write(line.data(using: .utf8)!)
                    try? fp.synchronize()
                }
                
                if curPos == 0 && ppgSerie.count == bufferLength{
                    
                    pastPPGSerie.removeAll()
                    pastPPGSerie.append(contentsOf: ppgSerie)
                    ppgSerie.removeAll()
                }
                
                ppgSerie.append((x: Double(curPos), y: (1100 - data)))
                
                if pastPPGSerie.count > 0{
                    pastPPGSerie.remove(at: 0)
                }
               
                curPos = (curPos + 1) % bufferLength
                
                processPPG(ts: ts, data: data)
                
                if !bPause && curPos % 5 == 0{
                    refreshChart()
                    bpmLabel.text = String(bpm)
                    metricsTableView.reloadData()
                    //print("BPM: \(bpm) Crest: \(crest) Creat Time: \(crestTime)")
                }
            }
            
            //print("PPG: \(ppgStr)")

        }
    }


}

extension ViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      //centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
      // scan any service
      centralManager.scanForPeripherals(withServices: nil)
    default:
        print("Unknown state")
    }
  }

  // when a peripheral is found from the scan, this function is called
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
    
    // found ppg BLE, stop scan and connect to it
    if peripheral.name == "ppg"{
        print(peripheral)
        heartRatePeripheral = peripheral
        heartRatePeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(heartRatePeripheral)
    }
  }
    
  // when conntion is successful, this function is called
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("PPG connected!")
    
    // dicover service of the peripheral provided by the PPG BLE
    heartRatePeripheral.discoverServices([ppgServiceCBUUID])
  }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("PPG disconnected!")
        bConnected = false
        centralManager.scanForPeripherals(withServices: nil)
    }
}

extension ViewController: CBPeripheralDelegate {
    
  // service is found
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  // when Characteristics is found, this function is called
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }

    for characteristic in characteristics {
        
      print(characteristic)

      //if characteristic.properties.contains(.read) {
      //  print("\(characteristic.uuid): properties contains .read")
      //  peripheral.readValue(for: characteristic)
      //}
        
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
          bConnected = true
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  // when notification is received, this function is called
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      
    switch characteristic.uuid {
        
        case ppgCharacteristicCBUUID:
        
            let ppg = leftover + ppgString(from: characteristic)
            leftover = ""
          
            // it has "\n", then split it
            if ppg.rangeOfCharacter(from: CharacterSet.newlines) != nil{
                    
                let arr = ppg.components(separatedBy: "\r\n")
                
                    for n in 0..<arr.count-1{
                    
                        onPPGReceived(arr[n])
                    }
                    
                    //last piece is the left over
                    leftover.append(contentsOf: arr[arr.count-1])
                
            }else{
                
                leftover.append(contentsOf: ppg)
            }
            
            default:
                print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }


  private func ppgString(from characteristic: CBCharacteristic) -> String {
      
    guard let characteristicData = characteristic.value else { return "" }
    let byteArray = [UInt8](characteristicData)
    
    if let string = String(bytes: byteArray, encoding: .utf8) {
          return string
      } else {
          print("not a valid UTF-8 sequence")
          return ""
      }
  }
    
}
