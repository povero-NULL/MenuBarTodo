//
//  GmailService.swift
//  MenuBarTodo
//
//  Created by 清水光希 on 2026/10/01.
//

import Foundation
import GoogleSignIn

// Gmail APIのレスポンスデコード用モデル
struct GmailThreadListResponse: Codable {
    struct ThreadItem: Codable {
        let id: String
        let snippet: String?
    }
    let threads: [ThreadItem]?
}

struct GmailThreadDetailResponse: Codable {
    struct Message: Codable {
        let id: String
        let payload: Payload?
    }
    struct Payload: Codable {
        let headers: [Header]?
    }
    struct Header: Codable {
        let name: String
        let value: String
    }
    let id: String
    let messages: [Message]?
}

class GmailService {
    static let shared = GmailService()
    private init() {}

    /// 指定したクエリ（例: label:1_未着手）に合致するスレッド一覧を取得
    func fetchThreads(query: String) async throws -> [TodoItem] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])
        }

        let token = user.accessToken.tokenString
        
        // 1. スレッド一覧のIDリストを取得
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let listUrlString = "https://gmail.googleapis.com/gmail/v1/users/me/threads?q=\(encodedQuery)&maxResults=10"
        guard let listUrl = URL(string: listUrlString) else { return [] }

        var request = URLRequest(url: listUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailService", code: 500, userInfo: [NSLocalizedDescriptionKey: "メール一覧の取得に失敗しました"])
        }

        let listResult = try JSONDecoder().decode(GmailThreadListResponse.self, from: data)
        guard let threads = listResult.threads, !threads.isEmpty else {
            return []
        }

        // 2. 各スレッドの詳細（件名と送信者）を取得
        var items: [TodoItem] = []
        let status: TaskStatus = query.contains("2_進行中") ? .inProgress : .notStarted

        for thread in threads {
            if let detail = try? await fetchThreadDetail(threadId: thread.id, token: token) {
                items.append(TodoItem(
                    threadId: detail.id,
                    subject: detail.subject,
                    sender: detail.sender,
                    status: status
                ))
            }
        }

        return items
    }

    /// スレッドの詳細から最新メッセージの件名と差出人を抽出
    private func fetchThreadDetail(threadId: String, token: String) async throws -> (id: String, subject: String, sender: String) {
        let detailUrlString = "https://gmail.googleapis.com/gmail/v1/users/me/threads/\(threadId)?format=metadata"
        guard let url = URL(string: detailUrlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let detailResult = try JSONDecoder().decode(GmailThreadDetailResponse.self, from: data)

        // 最新のメッセージからヘッダーを取得
        let headers = detailResult.messages?.last?.payload?.headers ?? []
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(件名なし)"
        let sender = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? "不明な差出人"

        // 差出人の整形（例: "山田 太郎 <yamada@example.com>" -> "山田 太郎"）
        let cleanSender = sender.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? sender

        return (id: detailResult.id, subject: subject, sender: cleanSender)
    }
}
