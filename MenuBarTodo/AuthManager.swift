//
//  AuthManager.swift
//  MenuBarTodo
//
//  Created by 清水光希 on 2026/10/01.
//

import Foundation
import SwiftUI
import GoogleSignIn
import Observation // 追記

@Observable
@MainActor
class AuthManager {
    var isSignedIn: Bool = false
    var userEmail: String = ""
    var errorMessage: String? = nil

    // ⚠️ GCPで発行されたクライアントID
    private let clientID = "949789689889-rmem8mdf5c6a07gb84j0amkmilr7tvrr.apps.googleusercontent.com"
    private let gmailScope = "https://www.googleapis.com/auth/gmail.modify"

    init() {
        checkPreviousSignIn()
    }

    /// アプリ起動時に前回のログイン状態を復帰する
        func checkPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                guard let self = self else { return }
                // メインスレッドで値を書き換える
                Task { @MainActor in
                    if let user = user {
                        self.isSignedIn = true
                        self.userEmail = user.profile?.email ?? "ログイン中"
                    } else {
                        self.isSignedIn = false
                    }
                }
            }
        }

        /// Googleログイン画面（ブラウザ）を開いて認証する
        func signIn() {
            guard let window = NSApplication.shared.windows.first else { return }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            GIDSignIn.sharedInstance.signIn(
                withPresenting: window,
                hint: nil,
                additionalScopes: [gmailScope]
            ) { [weak self] result, error in
                guard let self = self else { return }

                // メインスレッドで値を書き換える
                Task { @MainActor in
                    if let error = error {
                        self.errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
                        return
                    }

                    if let result = result {
                        self.isSignedIn = true
                        self.userEmail = result.user.profile?.email ?? "ログイン中"
                        self.errorMessage = nil
                    }
                }
            }
        }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.isSignedIn = false
        self.userEmail = ""
    }
}
