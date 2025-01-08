import Flutter
import UIKit
import CoreBluetooth

public class SwiftPrintBluetoothThermalPlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterPlugin {

    var centralManager: CBCentralManager?
    var discoveredDevices: [String] = []
    var connectedPeripheral: CBPeripheral?
    var targetCharacteristic: CBCharacteristic?
    var flutterResult: FlutterResult?
    var bytes: [UInt8]?
    var stringprint: String = ""

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "groons.web.app/print", binaryMessenger: registrar.messenger())
        let instance = SwiftPrintBluetoothThermalPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.flutterResult = result

        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "bluetoothenabled":
            result(centralManager?.state == .poweredOn)
        case "ispermissionbluetoothgranted":
            result(centralManager?.state == .poweredOn)
        case "pairedbluetooths":
            discoveredDevices = []
            centralManager?.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.centralManager?.stopScan()
                result(self.discoveredDevices)
            }
        case "connect":
            guard let macAddress = call.arguments as? String,
                  let uuid = UUID(uuidString: macAddress) else {
                result(false)
                return
            }
            if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
                connectedPeripheral = peripheral
                connectedPeripheral?.delegate = self
                centralManager?.connect(peripheral, options: nil)
                result(true)
            } else {
                result(false)
            }
        case "connectionstatus":
            result(connectedPeripheral?.state == .connected)
        case "writebytes":
            guard let arguments = call.arguments as? [UInt8],
                  let characteristic = targetCharacteristic else {
                result(false)
                return
            }
            writeDataInChunks(data: Data(arguments), characteristic: characteristic)
            result(true)
        case "printstring":
            guard let inputString = call.arguments as? String,
                  let characteristic = targetCharacteristic else {
                result(false)
                return
            }
            handlePrintString(inputString: inputString, characteristic: characteristic)
            result(true)
        case "disconnect":
            if let peripheral = connectedPeripheral {
                centralManager?.cancelPeripheralConnection(peripheral)
                targetCharacteristic = nil
                result(true)
            } else {
                result(false)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func writeDataInChunks(data: Data, characteristic: CBCharacteristic) {
        let chunkSize = 150
        var offset = 0
        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            connectedPeripheral?.writeValue(chunk, for: characteristic, type: .withoutResponse)
            offset += chunkSize
        }
        flutterResult?(true) // Notify Flutter that the write operation is complete
    }

    private func handlePrintString(inputString: String, characteristic: CBCharacteristic) {
        let sizeBytes: [[UInt8]] = [
            [0x1d, 0x21, 0x00],
            [0x1b, 0x4d, 0x01],
            [0x1b, 0x4d, 0x00],
            [0x1d, 0x21, 0x11],
            [0x1d, 0x21, 0x22],
            [0x1d, 0x21, 0x33]
        ]
        let resetBytes: [UInt8] = [0x1b, 0x40]

        var size = 2
        var text = inputString
        let components = inputString.components(separatedBy: "///")
        if components.count > 1 {
            size = Int(components[0]) ?? 2
            text = components[1]
            size = max(1, min(size, 5))
        }

        connectedPeripheral?.writeValue(Data(sizeBytes[size]), for: characteristic, type: .withoutResponse)
        connectedPeripheral?.writeValue(Data(text.utf8), for: characteristic, type: .withResponse)
        connectedPeripheral?.writeValue(Data(resetBytes), for: characteristic, type: .withoutResponse)
        flutterResult?(true) // Notify Flutter that the print operation is complete
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Handle Bluetooth state changes if needed
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, !discoveredDevices.contains(name) {
            discoveredDevices.append("\(name)#\(peripheral.identifier.uuidString)")
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        flutterResult?(false)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.writeWithoutResponse) {
                targetCharacteristic = characteristic
                break
            }
        }
    }
}




// import Flutter
// import UIKit
// import CoreBluetooth

// public class SwiftPrintBluetoothThermalPlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterPlugin {

//     var centralManager: CBCentralManager?
//     var discoveredDevices: [String] = []
//     var connectedPeripheral: CBPeripheral?
//     var targetCharacteristic: CBCharacteristic?
//     var flutterResult: FlutterResult?
//     var bytes: [UInt8]?
//     var stringprint: String = ""

//     override init() {
//         super.init()
//         centralManager = CBCentralManager(delegate: self, queue: nil)
//     }

//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let channel = FlutterMethodChannel(name: "groons.web.app/print", binaryMessenger: registrar.messenger())
//         let instance = SwiftPrintBluetoothThermalPlugin()
//         registrar.addMethodCallDelegate(instance, channel: channel)
//     }

//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         self.flutterResult = result

//         switch call.method {
//         case "getPlatformVersion":
//             result("iOS " + UIDevice.current.systemVersion)
//         case "bluetoothenabled":
//             result(centralManager?.state == .poweredOn)
//         case "ispermissionbluetoothgranted":
//             result(centralManager?.state == .poweredOn)
//         case "pairedbluetooths":
//             discoveredDevices = []
//             centralManager?.scanForPeripherals(withServices: nil, options: nil)
//             DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                 self.centralManager?.stopScan()
//                 result(self.discoveredDevices)
//             }
//         case "connect":
//             guard let macAddress = call.arguments as? String,
//                   let uuid = UUID(uuidString: macAddress) else {
//                 result(false)
//                 return
//             }
//             if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
//                 connectedPeripheral = peripheral
//                 connectedPeripheral?.delegate = self
//                 centralManager?.connect(peripheral, options: nil)
//                 result(true)
//             } else {
//                 result(false)
//             }
//         case "connectionstatus":
//             result(connectedPeripheral?.state == .connected)
//         case "writebytes":
//             guard let arguments = call.arguments as? [UInt8],
//                   let characteristic = targetCharacteristic else {
//                 result(false)
//                 return
//             }
//             writeDataInChunks(data: Data(arguments), characteristic: characteristic)
//             result(true)
//         case "printstring":
//             guard let inputString = call.arguments as? String,
//                   let characteristic = targetCharacteristic else {
//                 result(false)
//                 return
//             }
//             handlePrintString(inputString: inputString, characteristic: characteristic)
//             result(true)
//         case "disconnect":
//             if let peripheral = connectedPeripheral {
//                 centralManager?.cancelPeripheralConnection(peripheral)
//                 targetCharacteristic = nil
//                 result(true)
//             } else {
//                 result(false)
//             }
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }

//     // Helper Functions
//     private func writeDataInChunks(data: Data, characteristic: CBCharacteristic) {
//         let chunkSize = 150
//         var offset = 0
//         while offset < data.count {
//             let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
//             connectedPeripheral?.writeValue(chunk, for: characteristic, type: .withoutResponse)
//             offset += chunkSize
//         }
//     }

//     private func handlePrintString(inputString: String, characteristic: CBCharacteristic) {
//         let sizeBytes: [[UInt8]] = [
//             [0x1d, 0x21, 0x00],
//             [0x1b, 0x4d, 0x01],
//             [0x1b, 0x4d, 0x00],
//             [0x1d, 0x21, 0x11],
//             [0x1d, 0x21, 0x22],
//             [0x1d, 0x21, 0x33]
//         ]
//         let resetBytes: [UInt8] = [0x1b, 0x40]

//         var size = 2
//         var text = inputString
//         let components = inputString.components(separatedBy: "///")
//         if components.count > 1 {
//             size = Int(components[0]) ?? 2
//             text = components[1]
//             size = max(1, min(size, 5))
//         }

//         connectedPeripheral?.writeValue(Data(sizeBytes[size]), for: characteristic, type: .withoutResponse)
//         connectedPeripheral?.writeValue(Data(text.utf8), for: characteristic, type: .withResponse)
//         connectedPeripheral?.writeValue(Data(resetBytes), for: characteristic, type: .withoutResponse)
//     }

//     // CBCentralManagerDelegate
//     public func centralManagerDidUpdateState(_ central: CBCentralManager) {
//         // Handle Bluetooth state changes if needed
//     }

//     public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
//         if let name = peripheral.name, !discoveredDevices.contains(name) {
//             discoveredDevices.append("\(name)#\(peripheral.identifier.uuidString)")
//         }
//     }

//     public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//         peripheral.delegate = self
//         peripheral.discoverServices(nil)
//     }

//     public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//         connectedPeripheral = nil
//         flutterResult?(false)
//     }

//     // CBPeripheralDelegate
//     public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//         guard let services = peripheral.services else { return }
//         for service in services {
//             peripheral.discoverCharacteristics(nil, for: service)
//         }
//     }

//     public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
//         guard let characteristics = service.characteristics else { return }
//         for characteristic in characteristics {
//             if characteristic.properties.contains(.writeWithoutResponse) {
//                 targetCharacteristic = characteristic
//                 break
//             }
//         }
//     }
// }




