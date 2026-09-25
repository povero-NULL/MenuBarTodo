//
//  MenuBarTodoApp.swift
//  MenuBarTodo
//
//  Created by 清水光希 on 2026/09/26.
//

import SwiftUI

@main
struct MenuBarTodoApp: App {
    // debug start
    @State private var todos: [TodoItem] = [
        TodoItem(
            threadId: "mock_thread_1",
            subject: "【要確認】次期機能の仕様書レビュー",
            sender: "山田 太郎",
            status: .inProgress
        ),
        TodoItem(
            threadId: "mock_thread_2",
            subject: "見積書の送付依頼について",
            sender: "佐藤 花子",
            status: .notStarted
        ),
        TodoItem(
            threadId: "mock_thread_3",
            subject: "来週のキックオフミーティング日程調整",
            sender: "鈴木 一郎",
            status: .notStarted
        )
    ]
    // debug end
    
    var body: some Scene {
        MenuBarExtra("MenuBarTodo", systemImage: "checkmark.circle") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Gmail Tasks")
                        .font(.headline)
                    Spacer()
                    Button {
                        openNewEmailUrl()
                    } label: {
                        Label("新規メール", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Divider()
                
                // 1. 「2_進行中」ゾーン（1段目）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("進行中")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(todos.filter { $0.status == .inProgress }.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    let inProgressItems = todos.filter { $0.status == .inProgress }
                    if inProgressItems.isEmpty {
                        Text("現在進行中のタスクはありません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(inProgressItems) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Button {
                                    completeTask(item: item)
                                } label: {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .help("完了（全員に返信下書きを作成して開く）")

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.subject)
                                        .font(.body)
                                        .lineLimit(2)
                                    Text(item.sender)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(6)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }
                }

                Divider()

                // 2. 「1_未着手」エリア（一覧エリア）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("未着手")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(todos.filter { $0.status == .notStarted }.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ScrollView {
                        VStack(spacing: 6) {
                            let notStartedItems = todos.filter { $0.status == .notStarted }
                            if notStartedItems.isEmpty {
                                Text("未着手のタスクはありません")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(notStartedItems) { item in
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.subject)
                                                .font(.body)
                                                .lineLimit(1)
                                            Text(item.sender)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Button("着手") {
                                            moveToInProgress(item: item)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.06))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }

                Divider()

                // フッター
                HStack {
                    Spacer()
                    Button("アプリを終了") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
            }
            .padding(14)
            .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
    
    private func openNewEmailUrl() {
        if let url = URL(string: "https://mail.google.com/mail/u/0/?view=cm&fs=1"){
            NSWorkspace.shared.open(url)
        }
    }
    /// 「着手」ボタン: 1_未着手 → 2_進行中 へステータスを変更
    private func moveToInProgress(item: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == item.id }) {
            todos[index].status = .inProgress
        }
    }

    /// 「完了チェック」ボタン: 本来は下書き作成API後に遷移（Step 1ではブラウザ遷移のテスト）
    private func completeTask(item: TodoItem) {
        // 対象のメールスレッドを開くURL（Step 5で下書き自動生成に拡張）
        if let url = URL(string: "https://mail.google.com/mail/u/0/#inbox") {
            NSWorkspace.shared.open(url)
        }
        
        // リストから削除
        todos.removeAll(where: { $0.id == item.id })
    }
}
