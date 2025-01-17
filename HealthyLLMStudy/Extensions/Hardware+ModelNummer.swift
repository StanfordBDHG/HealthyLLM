//
//  Hardware+ModelNummer.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/8/25.
//

import Foundation

enum Hardware {
    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()
    
    
    static let watchModel: String? = {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: &machine, encoding: String.Encoding.utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
