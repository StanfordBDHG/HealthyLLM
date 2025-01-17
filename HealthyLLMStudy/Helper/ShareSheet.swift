//
//  ShareSheet.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/8/25.
//

import SwiftUI
import UIKit

enum ExportFormat {
    case txt
    case json
    case custom(String)
}

struct ShareSheet: UIViewControllerRepresentable {
    let sharedItem: Data
    let sharedItemType: ExportFormat
    
    func makeUIViewController(context: Context) -> some UIActivityViewController {
        let temporaryPath = temporaryExportFilePath(sharedItemType: sharedItemType)
        try? sharedItem.write(to: temporaryPath)
        
        let controller = UIActivityViewController(
            activityItems: [temporaryPath],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: temporaryPath)
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    
    private func temporaryExportFilePath(sharedItemType: ExportFormat) -> URL {
        let temporaryPath = FileManager.default.temporaryDirectory.appendingPathComponent("HealthyLLMStudyData-\(UUID().uuidString)")
        
        switch sharedItemType {
        case .txt:
            return temporaryPath.appendingPathExtension("txt")
        case .json:
            return temporaryPath.appendingPathExtension("json")
        case .custom(let `extension`):
            return temporaryPath.appendingPathExtension("\(`extension`)")
        }
    }
}
