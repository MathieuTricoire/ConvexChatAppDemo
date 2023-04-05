//
//  ContentView.swift
//  ConvexChatApp
//
//  Created by Mathieu Tricoire on 2023-04-03.
//

import Convex
import SwiftUI

let path = Bundle.main.path(forResource: "Secret", ofType: "plist")!
let secret = NSDictionary(contentsOfFile: path)!
let CONVEX_URL_STRING = secret["CONVEX_URL"] as! String
let CONVEX_URL = URL(string: CONVEX_URL_STRING)!

struct Message: ConvexIdentifiable, Codable, Equatable {
    let _id: ConvexId
    @ConvexCreationTime
    var _creationTime: Date
    let author: String
    let body: String
}

struct ContentView: View {
    private var client = Convex(CONVEX_URL)
    private let dateFormatter: DateFormatter

    @AppStorage("username") private var username = ""
    @State private var messages: [Message] = []
    @State private var showUsernameAlert = false
    @State private var newUsername = ""

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
    }

    func listMessages() async {
        if let messages: [Message] = try? await client.query("listMessages") {
            self.messages = messages
        }
    }

    func sendMessage(_ message: String) async {
        let args: ConvexValue = [
            "author": .string(username),
            "body": .string(message),
        ]
        _ = try? await client.mutation("sendMessage", args)
        await listMessages()
    }

    func changeUsername() {
        if newUsername.trimmingCharacters(in: .whitespaces).isEmpty { return }
        username = newUsername
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(messages.reversed()) { message in
                        VStack(alignment: .leading) {
                            Text("**\(message.author)**: \(message.body)")
                            Text(message._creationTime, formatter: dateFormatter)
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                    }
                }
                .animation(.easeIn, value: messages)
                .refreshable {
                    await listMessages()
                }
                CustomTextField { message in
                    Task {
                        await sendMessage(message)
                    }
                }
                .background(.ultraThickMaterial)
            }
            .navigationTitle(username)
            .toolbar {
                Button {
                    newUsername = username
                    showUsernameAlert.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
                .alert("Change username", isPresented: $showUsernameAlert) {
                    TextField("Enter your username", text: $newUsername)
                    Button("Change", action: changeUsername)
                }
            }
        }
        .task {
            await listMessages()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            if username == "" {
                let userId = Int.random(in: 1111 ... 9999)
                username = "User \(userId)"
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// From: https://medium.com/@ckinetandrii/i-have-created-an-auto-resizing-textfield-using-swiftui-5839bb075a64
struct CustomTextField: View {
    @State var message: String = ""
    var action: (String) async -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 8) {
                withAnimation(.easeInOut) {
                    TextField("", text: $message, axis: .vertical)
                        .placeholder(when: message.isEmpty) {
                            Text("Message...")
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(...7)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.background)
            .cornerRadius(10)

            Button {
                Task {
                    await action(message)
                    message = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.largeTitle)
            }
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines) == "")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 55)
        .animation(.easeInOut(duration: 0.3), value: message)
    }
}

extension View {
    func placeholder(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> some View
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }

    func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}
