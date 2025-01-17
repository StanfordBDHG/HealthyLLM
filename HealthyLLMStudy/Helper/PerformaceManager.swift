//
//  PerformaceManager.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/15/25.
//

import Foundation
import Spezi
import os


class PerformaceManager: DefaultInitializable, Module, EnvironmentAccessible {
    private let logger = Logger(subsystem: "HealthyLLMStudy", category: "PerformaceManager")
    private(set) var recording: Bool = false
    private var timer: Timer? = nil
    private var logs: [String: String] = [:]
    
    required init() { }
    
    
    func startRecording() {
        guard !recording else { return }
        logs = [:]
        recording = true
        timer = .scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.log()
        })
    }
    
    func stopRecording() -> [String: String] {
        timer?.invalidate()
        timer = nil
        recording = false
        return logs
    }
    
    private func log() {
        logs["\(Date().timeIntervalSince1970)"] = "\(cpuUsage) \(memoryUsage)"
    }
    
    private var cpuUsage: String {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    break
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return "cpu: \(totalUsageOfCPU.formatted(.number.precision(.significantDigits(3))))%"
        
    }
    
    private var memoryUsage: String {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }
        
        let total = ProcessInfo.processInfo.physicalMemory
        return "memory: (\(used.formatted(.byteCount(style: .memory, allowedUnits: .mb))) / \(total.formatted(.byteCount(style: .memory, allowedUnits: .mb))))"
    }
    
    static var storageUsage: String {
        let free = ByteCountFormatter.string(fromByteCount: freeDiskSpaceInBytes, countStyle: ByteCountFormatter.CountStyle.decimal)
        let total = ByteCountFormatter.string(fromByteCount: totalDiskSpaceInBytes, countStyle: ByteCountFormatter.CountStyle.decimal)
        
        return "storage: \(free) / \(total)GB"
    }

    private static var totalDiskSpaceInBytes: Int64 {
        guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
              let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value else { return 0 }
        return space
    }
    
    
    private static var freeDiskSpaceInBytes: Int64 {
        if let space = try? URL(fileURLWithPath: NSHomeDirectory() as String)
            .resourceValues(forKeys: [URLResourceKey.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage {
            return space
        } else {
            return 0
        }
    }
}
