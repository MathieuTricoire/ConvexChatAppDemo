//
//  MessagesView.swift
//  ConvexChatApp
//
//  Created by Mathieu Tricoire on 2023-05-03.
//

import Convex
import SwiftUI

struct MessagesView: View {
    @Environment(\.convexClient) private var client

    @AppStorage("username") private var username = ""

    @ConvexQuery(\.listMessages) private var messages

    @State private var showingSheet = false
    @State private var showUsernameAlert = false
    @State private var newUsername = ""

    private let dateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    func sendMessage(_ body: String) {
        Task {
            try? await client?.mutation(path: "sendMessage", args: ["author": .string(value: username), "body": .string(value:  body)])
        }
    }

    func changeUsername() {
        if newUsername.trimmingCharacters(in: .whitespaces).isEmpty { return }
        username = newUsername
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if case let .array(messages) = messages {
                    List {
                        ForEach(messages, id: \.[dynamicMember: "_id"]) { message in
                            VStack(alignment: .leading) {
                                Text("**\(message.author?.description ?? "")**: \(message.body?.description ?? "")")
                                if case let .some(.float(creationTime)) = message._creationTime {
                                    Text(Date(timeIntervalSince1970: creationTime / 1000), formatter: dateFormatter)
                                        .font(.caption)
                                        .foregroundColor(Color.gray)
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .animation(.easeIn, value: messages)
                } else {
                    VStack {
                        Spacer()
                        Text("~ no messages ~")
                        Spacer()
                    }
                }

                CustomTextField { message in
                    sendMessage(message)
                }
                .background(.ultraThickMaterial)
            }
            .toolbar {
                Button {
                    newUsername = username
                    showUsernameAlert.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
                .alert("Change username", isPresented: $showUsernameAlert) {
                    TextField("Enter your username", text: $newUsername)
                    Button("Change", action: { changeUsername() })
                }
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
}

struct MessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MessagesView()
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

    @MainActor
    func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}
