//
//  BLEPhotoReceiver.swift
//  LivePhotos
//
//  Created by Anupama Sharma on 6/29/25.
//
import UIKit
import CoreBluetooth

class BLEPhotoReceiver: NSObject, ObservableObject {
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    
    // Same UUIDs as ESP32
    private let serviceUUID = CBUUID(string: "53824b19-7dd7-472f-af8f-a3b012083960")
    private let dataCharacteristicUUID = CBUUID(string: "f8b1c759-7f9d-41a6-a6ba-0a04158ce13b")
    private let controlCharacteristicUUID = CBUUID(string: "5c32a506-613c-40a7-b477-8fd21a5f9325")
    
    // Photo reception state
    private var photoChunks: [Data] = []
    private var expectedPhotoSize: Int = 0
    private var receivedBytes: Int = 0
    private var isReceiving: Bool = false
    private var lastPhotoTimestamp: UInt32 = 0
    
    // Published properties for SwiftUI
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var receivedImage: UIImage?
    @Published var statusMessage: String = "Ready to scan"
    @Published var transferProgress: Float = 0.0
    
    // Delegate callback
    weak var delegate: BLEPhotoReceiverDelegate?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "Bluetooth not available"
            return
        }
        
        isScanning = true
        statusMessage = "Scanning for ESP32-S3 Camera..."
        
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            if self.isScanning {
                self.stopScanning()
                self.statusMessage = "Scan timeout - no device found"
            }
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func capturePhoto() {
        /*
        guard let characteristic = controlCharacteristic,
              let peripheral = peripheral else {
            statusMessage = "Not connected to device"
            return
        }
        
        let command = "CAPTURE".data(using: .utf8)!
        peripheral.writeValue(command, for: characteristic, type: .withResponse)
         */
        statusMessage = "Waiting for photo"
    }
    
    // MARK: - Private Methods
    private func handleDataReceived(_ data: Data) {
        print("Data length: \(data.count) bytes")
        //print("Raw bytes: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        if let dataString = String(data: data, encoding: .utf8) {
            print("As UTF-8 string: '\(dataString)'")
            
            if dataString.hasPrefix("START:") {
                print("FOUND START COMMAND")
                
                // Parse: START:size:timestamp
                let components = dataString.dropFirst(6).components(separatedBy: ":")
                let fullSizeString = components[0]
                let sizeString = fullSizeString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check for timestamp (optional)
                var timestamp: UInt32 = 0
                
                if components.count > 1 {
                    timestamp = UInt32(components[1]) ?? 0
                    print("Photo timestamp: \(timestamp)")
                                    
                    // Check if this is an old photo
                    if timestamp <= lastPhotoTimestamp && lastPhotoTimestamp > 0 {
                        print("WARNING: Ignoring old photo (timestamp \(timestamp) <= \(lastPhotoTimestamp))")
                        return
                    }
                    lastPhotoTimestamp = timestamp
                }
                
                print("Full size string: '\(fullSizeString)'")
                print("Trimmed size string: '\(sizeString)'")
                print("Size string length: \(sizeString.count)")
                print("Size string characters: \(Array(sizeString))")
                
                if let parsedSize = Int(sizeString) {
                    // Reset reception state BEFORE setting new expected size
                    photoChunks.removeAll()
                    receivedBytes = 0
                    transferProgress = 0.0
                    expectedPhotoSize = parsedSize
                    isReceiving = true
                    print("Successfully parsed size: \(expectedPhotoSize)")
                } else {
                    print("ERROR: Failed to parse size from string '\(sizeString)'")
                    // Try to extract just the numeric characters
                    let numericString = sizeString.filter { $0.isNumber }
                    print("Trying numeric-only string: '\(numericString)'")
                    expectedPhotoSize = Int(numericString) ?? 0
                    print("Fallback parsed size: \(expectedPhotoSize)")
                }
                statusMessage = "Receiving photo (\(expectedPhotoSize) bytes)"
                print("Starting photo reception: \(expectedPhotoSize) bytes")
                return
                
            } else if dataString == "END" {
                // End of photo
                print("Received END marker")
                if isReceiving {
                    assemblePhoto()
                }
                isReceiving = false
                return
                
            } else if isReceiving {
                // This might be binary data that couldn't be decoded as string
                handlePhotoChunk(data)
                return
            }
        }
        
        if isReceiving {
            // Binary photo data chunk
            handlePhotoChunk(data)
        } else {
            print("Received binary data when not expecting photo data")
        }
    }
    
    private func handlePhotoChunk(_ data: Data) {
        photoChunks.append(data)
        receivedBytes += data.count
        
        if expectedPhotoSize > 0 {
            transferProgress = Float(receivedBytes) / Float(expectedPhotoSize)
        }
        
        statusMessage = "Receiving: \(receivedBytes)/\(expectedPhotoSize) bytes"
        print("Received chunk: \(receivedBytes)/\(expectedPhotoSize) bytes")
    }
    
    private func assemblePhoto() {
        
        // Verify we received the expected amount of data
        if expectedPhotoSize > 0 && receivedBytes != expectedPhotoSize {
            print("WARNING: Expected \(expectedPhotoSize) bytes but received \(receivedBytes) bytes")
        }
        
        print("Assembling photo: \(photoChunks.count) chunks, \(receivedBytes) bytes out of \(expectedPhotoSize) expected bytes")
        
        // Combine all chunks into single Data object
        var photoData = Data()
        for (index, chunk) in photoChunks.enumerated() {
            photoData.append(chunk)
            print("Chunk \(index): \(chunk.count) bytes")
        }
        print("Final photo data size: \(photoData.count) bytes")
        // Log first few bytes to verify JPEG header
        if photoData.count >= 4 {
            let header = photoData.prefix(4)
            print("Photo header bytes: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    
            // JPEG should start with FF D8 FF
            if photoData[0] == 0xFF && photoData[1] == 0xD8 && photoData[2] == 0xFF {
                print("Valid JPEG header detected")
            } else {
                print("WARNING: Invalid JPEG header")
            }
        }
        
        // Convert to UIImage
        if let image = UIImage(data: photoData) {
            DispatchQueue.main.async {
                self.receivedImage = image
                self.statusMessage = "Photo received successfully!"
                self.transferProgress = 1.0
                self.delegate?.didReceivePhoto(image)
            }
            print("Photo assembled successfully: \(photoData.count) bytes")
        } else {
            DispatchQueue.main.async {
                self.statusMessage = "Failed to decode photo"
                self.delegate?.didFailWithError("Failed to decode photo")
            }
            print("Failed to decode photo data")
        }
        
        // reset photo reception state
        photoChunks.removeAll()
        receivedBytes = 0
        transferProgress = 0.0
        expectedPhotoSize = 0
        isReceiving = false
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEPhotoReceiver: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            statusMessage = "Bluetooth is off"
        case .resetting:
            statusMessage = "Bluetooth resetting"
        case .unauthorized:
            statusMessage = "Bluetooth unauthorized"
        case .unsupported:
            statusMessage = "Bluetooth unsupported"
        case .unknown:
            statusMessage = "Bluetooth state unknown"
        @unknown default:
            statusMessage = "Unknown Bluetooth state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        print("Advertisement data: \(advertisementData)")
        
        if let name = peripheral.name, name.contains("TANGO") {
            print("Found ESP32 device, attempting to connect...")
            
            
            self.peripheral = peripheral
            peripheral.delegate = self
            
            stopScanning()
            statusMessage = "Connecting to ESP32-S3..."
            centralManager.connect(peripheral, options: nil)
        } else {
            print("Skipping device: \(peripheral.name ?? "Unknown")")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        isConnected = true
        statusMessage = "Connected - discovering services..."
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        statusMessage = "Connection failed"
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral")
        isConnected = false
        statusMessage = "Disconnected"
        self.peripheral = nil
        dataCharacteristic = nil
        controlCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BLEPhotoReceiver: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            statusMessage = "Service discovery failed"
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            statusMessage = "Camera service not found"
            return
        }
        
        statusMessage = "Discovering characteristics..."
        peripheral.discoverCharacteristics([dataCharacteristicUUID, controlCharacteristicUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            statusMessage = "Characteristic discovery failed"
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case dataCharacteristicUUID:
                dataCharacteristic = characteristic
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to data characteristic")
                
            case controlCharacteristicUUID:
                controlCharacteristic = characteristic
                print("Found control characteristic")
                
            default:
                break
            }
        }
        
        if dataCharacteristic != nil { //&& controlCharacteristic != nil {
            statusMessage = "Ready to capture photos"
            delegate?.didConnect()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error reading characteristic: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == dataCharacteristicUUID {
            handleDataReceived(data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing characteristic: \(error.localizedDescription)")
            statusMessage = "Command failed"
        } else {
            print("Successfully wrote to characteristic")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
        } else {
            print("Notification state updated for characteristic: \(characteristic.uuid)")
        }
    }
}

// MARK: - Delegate Protocol
protocol BLEPhotoReceiverDelegate: AnyObject {
    func didConnect()
    func didReceivePhoto(_ image: UIImage)
    func didFailWithError(_ error: String)
}
