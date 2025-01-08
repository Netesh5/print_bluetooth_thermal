import Flutter
import UIKit
import CoreBluetooth

public class SwiftPrintBluetoothThermalPlugin: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterPlugin {

    var centralManager: CBCentralManager?
    var discoveredDevices: [String] = []
    var connectedPeripheral: CBPeripheral?
    var targetService: CBService?
    var targetCharacteristic: CBCharacteristic?

    var flutterResult: FlutterResult?
    var bytes: [UInt8]?
    var stringprint = ""

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
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
            let iosVersion = UIDevice.current.systemVersion
            result("iOS " + iosVersion)
        case "getBatteryLevel":
            let device = UIDevice.current
            let batteryLevel = device.batteryLevel * 100
            result(Int(batteryLevel))
        case "bluetoothenabled":
            result(centralManager?.state == .poweredOn)
        case "ispermissionbluetoothgranted":
            result(centralManager?.state == .poweredOn)
        case "pairedbluetooths":
            scanForBluetoothDevices(result: result)
        case "connect":
            if let macAddress = call.arguments as? String {
                connectToDevice(macAddress: macAddress, result: result)
            } else {
                result(false)
            }
        case "connectionstatus":
            result(connectedPeripheral?.state == .connected)
        case "writebytes":
            if let arguments = call.arguments as? [UInt8] {
                writeBytes(arguments, result: result)
            } else {
                result(false)
            }
        case "printstring":
            if let string = call.arguments as? String {
                printString(string, result: result)
            } else {
                result(false)
            }
        case "disconnect":
            disconnectDevice(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func scanForBluetoothDevices(result: @escaping FlutterResult) {
        discoveredDevices.removeAll()
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.centralManager?.stopScan()
            result(self.discoveredDevices)
        }
    }

    private func connectToDevice(macAddress: String, result: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: macAddress) else {
            result(false)
            return
        }
        let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals?.first else {
            result(false)
            return
        }
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager?.connect(peripheral, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            result(peripheral.state == .connected)
        }
    }

    private func writeBytes(_ bytes: [UInt8], result: @escaping FlutterResult) {
        guard let characteristic = targetCharacteristic else {
            result(false)
            return
        }
        let data = Data(bytes)
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func printString(_ string: String, result: @escaping FlutterResult) {
        guard let characteristic = targetCharacteristic else {
            result(false)
            return
        }
        let data = Data(string.utf8)
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }

    private func disconnectDevice(result: @escaping FlutterResult) {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            targetCharacteristic = nil
            result(true)
        } else {
            result(false)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let deviceName = peripheral.name {
            let deviceAddress = peripheral.identifier.uuidString
            let device = "\(deviceName)#\(deviceAddress)"
            if !discoveredDevices.contains(device) {
                discoveredDevices.append(device)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            flutterResult?(false)
        } else {
            flutterResult?(true)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        if let services = peripheral.services {
            for service in services {
                let targetServiceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
                let targetServiceUUID2 = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
                if service.uuid == targetServiceUUID || service.uuid == targetServiceUUID2 {
                    peripheral.discoverCharacteristics(nil, for: service)
                    targetService = service
                }
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                let targetCharacteristicUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
                let targetCharacteristicUUID2 = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
                if characteristic.uuid == targetCharacteristicUUID || characteristic.uuid == targetCharacteristicUUID2 {
                    targetCharacteristic = characteristic
                    break
                }
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            flutterResult?(false)
            print("Error writing value: \(error.localizedDescription)")
        } else {
            flutterResult?(true)
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
}
