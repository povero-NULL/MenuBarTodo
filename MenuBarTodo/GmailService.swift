//
//  GmailService.swift
//  MenuBarTodo
//
//  Created by 清水光希 on 2026/10/01.
//

import Foundation
import GoogleSignIn

struct GmailThreadListResponse: Codable {
    struct ThreadItem: Codable {
        let id: String
        let snippet: String?
    }
    let threads: [ThreadItem]?
    let nextPageToken: String? // ← これを追加！
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

// ラベル一覧取得用モデル
struct GmailLabelListResponse: Codable {
    struct LabelItem: Codable {
        let id: String
        let name: String
    }
    let labels: [LabelItem]?
}

// MARK: - GmailService

class GmailService {
    static let shared = GmailService()
    private init() {}

    // ラベル名とLabel IDのキャッシュ（都度全件検索するのを防ぐ）
    private var labelIdCache: [String: String] = [:]

    private func getAccessToken() throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーがログインしていません"])
        }
        return user.accessToken.tokenString
    }

    /// ラベル名から内部Label IDを取得（キャッシュがあればそれを返す）
    func getLabelId(name: String) async throws -> String {
        if let cached = labelIdCache[name] {
            return cached
        }

        let token = try getAccessToken()
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/labels")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailService", code: 500, userInfo: [NSLocalizedDescriptionKey: "ラベル一覧の取得に失敗しました"])
        }

        let list = try JSONDecoder().decode(GmailLabelListResponse.self, from: data)
        guard let labels = list.labels else {
            throw NSError(domain: "GmailService", code: 404, userInfo: [NSLocalizedDescriptionKey: "ラベルが見つかりませんでした"])
        }

        for label in labels {
            labelIdCache[label.name] = label.id
        }

        if let targetId = labelIdCache[name] {
            return targetId
        } else {
            throw NSError(domain: "GmailService", code: 404, userInfo: [NSLocalizedDescriptionKey: "ラベル「\(name)」が見つかりません。Gmail上で作成されているか確認してください。"])
        }
    }

    /// スレッド一覧を取得
    /// 指定したクエリに合致するスレッドを全件取得（ページネーション対応）
    func fetchThreads(query: String) async throws -> [TodoItem] {
        let token = try getAccessToken()
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var allThreadItems: [GmailThreadListResponse.ThreadItem] = []
        var pageToken: String? = nil

        // nextPageToken が無くなるまでループして全件のIDを集める
        repeat {
            var urlString = "https://gmail.googleapis.com/gmail/v1/users/me/threads?q=\(encodedQuery)&maxResults=100"
            if let token = pageToken {
                urlString += "&pageToken=\(token)"
            }
            
            guard let listUrl = URL(string: urlString) else { break }

            var request = URLRequest(url: listUrl)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "GmailService", code: 500, userInfo: [NSLocalizedDescriptionKey: "メール一覧の取得に失敗しました"])
            }

            let listResult = try JSONDecoder().decode(GmailThreadListResponse.self, from: data)
            if let threads = listResult.threads {
                allThreadItems.append(contentsOf: threads)
            }

            // 次のページがあるか更新（無ければ nil になってループ終了）
            pageToken = listResult.nextPageToken
        } while pageToken != nil

        guard !allThreadItems.isEmpty else {
            return []
        }

        // 各スレッドの詳細（件名と送信者）を取得
        var items: [TodoItem] = []
        let status: TaskStatus = query.contains("2_進行中") ? .inProgress : .notStarted

        for thread in allThreadItems {
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

    private func fetchThreadDetail(threadId: String, token: String) async throws -> (id: String, subject: String, sender: String) {
        let detailUrlString = "https://gmail.googleapis.com/gmail/v1/users/me/threads/\(threadId)?format=metadata"
        guard let url = URL(string: detailUrlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let detailResult = try JSONDecoder().decode(GmailThreadDetailResponse.self, from: data)

        let headers = detailResult.messages?.last?.payload?.headers ?? []
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(件名なし)"
        let sender = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? "不明な差出人"
        let cleanSender = sender.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? sender

        return (id: detailResult.id, subject: subject, sender: cleanSender)
    }

    /// スレッドのラベルを付け替える（Update処理）
    func modifyThreadLabels(threadId: String, addLabelIds: [String], removeLabelIds: [String]) async throws {
        let token = try getAccessToken()
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/threads/\(threadId)/modify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: [String]] = [
            "addLabelIds": addLabelIds,
            "removeLabelIds": removeLabelIds
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailService", code: 500, userInfo: [NSLocalizedDescriptionKey: "ラベルの更新に失敗しました"])
        }
    }
}
