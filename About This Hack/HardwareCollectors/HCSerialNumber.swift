import Foundation

class HCSerialNumber {
    static let shared = HCSerialNumber()
    private init() {}
    
    private lazy var HardwareInfo: (serialNumber: String, details: String) = {
        ATHLogger.debug("Initializing Serial Number & Hardware Info...", category: .hardware)
        
        // To avoid race condition on app launch, first, try IORegistry which is fast and locale-independent.
        let ioRegSerial = getIORegValueOSStringAsString(path: "IOService:/", key: "IOPlatformSerialNumber", encode: "y")

        var serialNumber = ioRegSerial.trimmingCharacters(in: .whitespacesAndNewlines)

        if !serialNumber.isEmpty {
            ATHLogger.debug("Serial number obtained from IORegistry: \(serialNumber)", category: .hardware)
        }
        
        // Race condition on initial app launch. Caches empty. Sleep for sometime to give cached data time to load
        Thread.sleep(forTimeInterval: 0.65)

        // Fallback: use cached data from HardwareCollector (hw.txt) if IORegistry did not return anything.
        // Use cached data from HardwareCollector
        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.hwFilePath) else {
            if serialNumber.isEmpty {
                ATHLogger.error("No hardware info available from HardwareCollector for serial number and IORegistry did not return anything.", category: .hardware)
                return ("", "")
             } else {
                 ATHLogger.warning("Using IORegistry serial number; hardware file not available for additional details.", category: .hardware)
                 return (serialNumber, "")
             }
        }
        
        ATHLogger.debug("Successfully retrieved hardware info from HardwareCollector for serial number.", category: .hardware)
        
        let lines = content.components(separatedBy: .newlines)
        
        // If IORegistry did not give us a serial, try to parse one from hw.txt (may be localized).
        if serialNumber.isEmpty {
            serialNumber = lines.first { $0.contains("Serial") }?
                .components(separatedBy: .whitespaces)
                .last ?? ""
            ATHLogger.debug("Parsed Serial Number: \(serialNumber)", category: .hardware)
        }
        
        let relevantKeys = [
            "System Firmware Version", "OS Loader Version", "SMC Version",
            "Apple ROM Info:", "Board-ID :", "Hardware UUID:", "Provisioning UDID:"
        ]
        
        let formattedDetails = lines
            .filter { line in relevantKeys.contains { line.contains($0) } }
            .map { "      " + $0.trimmingCharacters(in: .whitespaces) }
            .map { line in
                line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
        ATHLogger.debug("Formatted Hardware Details: \n\(formattedDetails)", category: .hardware)
        
        return (serialNumber, formattedDetails)
    }()
    
    func getSerialNumber() -> String {
        ATHLogger.debug("Getting serial number string...", category: .hardware)
        return HardwareInfo.serialNumber
    }
    
    func getHardwareInfo() -> String {
        ATHLogger.debug("Getting hardware info details string...", category: .hardware)
        return HardwareInfo.details
    }
}
