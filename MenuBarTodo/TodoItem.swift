//
//  TodoItem.swift
//  MenuBarTodo
//
//  Created by 清水光希 on 2026/09/26.
//

import Foundation

enum TaskStatus: String{
    case notStarted = "1_未着手"
    case inProgress = "2_進行中"
}

struct TodoItem: Identifiable {
    let id: UUID = UUID()
    let threadId: String       // GmailのスレッドID（仮データ）
    var subject: String        // メール件名 / タスク名
    var sender: String         // 差出人
    var status: TaskStatus     // ラベルステータス
}
