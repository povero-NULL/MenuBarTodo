import SwiftUI
import GoogleSignIn

@main
struct MenuBarTodoApp: App {
    @State private var authManager = AuthManager()

    // 取得したタスク一覧（初期値は空）
    @State private var todos: [TodoItem] = []
    
    // 読み込み中フラグとエラーメッセージ
    @State private var isLoading: Bool = false
    @State private var fetchErrorMessage: String? = nil

    var body: some Scene {
        MenuBarExtra("MenuBarTodo", systemImage: authManager.isSignedIn ? "checkmark.circle.fill" : "person.crop.circle.badge.exclamationmark") {
            VStack(alignment: .leading, spacing: 14) {
                // ヘッダー: タイトル、更新ボタン & 新規作成ボタン
                HStack {
                    Text("Gmail Tasks")
                        .font(.headline)
                    Spacer()
                    
                    if authManager.isSignedIn {
                        Button {
                            Task {
                                await loadEmails()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("タスクを更新")
                        .disabled(isLoading)
                    }

                    Button {
                        openNewEmailUrl()
                    } label: {
                        Label("新規メール", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Divider()

                // 認証ステータスエリア
                if authManager.isSignedIn {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.green)
                        Text(authManager.userEmail)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button("ログアウト") {
                            authManager.signOut()
                            todos.removeAll()
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    VStack(spacing: 6) {
                        Text("Gmailと連携してタスクを読み込みます")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            authManager.signIn()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Googleアカウントでログイン")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                }

                // ローディング表示 または エラー表示
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("メールを取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else if let error = fetchErrorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.vertical, 2)
                }

                Divider()

                // 1. 「2_進行中」エリア
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
                    if inProgressItems.isEmpty && !isLoading {
                        Text("進行中のタスクはありません")
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
                                .help("完了（該当メールを開く）")

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

                // 2. 「1_未着手」エリア
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

                    // ⬇️ ここから修正
                    let notStartedItems = todos.filter { $0.status == .notStarted }
                    
                    if notStartedItems.isEmpty && !isLoading {
                        Text("未着手のタスクはありません")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) { // 縦方向とインジケータを明示
                            VStack(spacing: 6) {
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
                            .padding(.trailing, 2) // スクロールバーと重ならない余白
                        }
                        .frame(height: 160) // ⚠️ maxHeight ではなく固定 height にする
                    }
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            // ログイン状態が変化した時（ログイン成功時）に自動取得
            .onChange(of: authManager.isSignedIn) { _, signedIn in
                if signedIn {
                    Task {
                        await loadEmails()
                    }
                }
            }
            // 起動時にすでにログイン済みならメールを取得
            .task {
                if authManager.isSignedIn {
                    await loadEmails()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - API連携処理

    /// Gmailから「1_未着手」と「2_進行中」のメールを取得
    private func loadEmails() async {
        guard authManager.isSignedIn else { return }
        
        isLoading = true
        fetchErrorMessage = nil

        do {
            // 並行して両方のラベルを検索取得
            async let notStarted = GmailService.shared.fetchThreads(query: "label:1_未着手")
            async let inProgress = GmailService.shared.fetchThreads(query: "label:2_進行中")

            let (fetchedNotStarted, fetchedInProgress) = try await (notStarted, inProgress)

            self.todos = fetchedInProgress + fetchedNotStarted
        } catch {
            self.fetchErrorMessage = "メール取得エラー: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Actions

    private func openNewEmailUrl() {
        if let url = URL(string: "https://mail.google.com/mail/u/0/?view=cm&fs=1") {
            NSWorkspace.shared.open(url)
        }
    }

    private func moveToInProgress(item: TodoItem) {
        // Step 4 で Gmail API 側のラベル更新処理を結合します
        if let index = todos.firstIndex(where: { $0.id == item.id }) {
            todos[index].status = .inProgress
        }
    }

    private func completeTask(item: TodoItem) {
        // 該当スレッドのブラウザURLを開く（GmailのスレッドURL形式）
        if let url = URL(string: "https://mail.google.com/mail/u/0/#inbox/\(item.threadId)") {
            NSWorkspace.shared.open(url)
        }
        todos.removeAll(where: { $0.id == item.id })
    }
}
