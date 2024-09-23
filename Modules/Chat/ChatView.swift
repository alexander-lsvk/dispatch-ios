//
//  ChatView.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 06.09.24.
//

import SwiftUI
import Combine

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    @State var typingMessage = ""
    @State var presentSubscription = true
    @State private var showToast = false
    
    @ObservedObject private var keyboard = KeyboardResponder()
    
    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().tableFooterView = UIView()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { scrollView in
                    List {
                        ForEach(viewModel.messages, id: \.self) { message in
                            withAnimation {
                                MessageView(message: message)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                HStack(spacing: 10) {
                    TextField("Message", text: $typingMessage)
                        .font(.system(size: 16))
                        .lineSpacing(6)
                        .textFieldStyle(OvalTextFieldStyle())
                        .frame(minHeight: 40)
                    
                    Button(action: sendMessage) {
                        Color.black
                            .frame(width: 30, height: 30)
                            .cornerRadius(15)
                            .overlay {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                    }
                    .opacity(viewModel.sendButtonActive ? 1.0 : 0.3)
                    .disabled(!viewModel.sendButtonActive)
                }
                .frame(minHeight: 50)
                .padding(.horizontal, 20)
            }
            .navigationBarTitle("Dispatch", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        
                    } label: {
                        Text(viewModel.publicKey ?? "")
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black)
                            .cornerRadius(12)
                            .frame(width: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(.bottom, keyboard.currentHeight)
            .edgesIgnoringSafeArea(keyboard.currentHeight == 0.0 ? .leading: .bottom)
            .onTapGesture {
                endEditing(true)
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
    
    func sendMessage() {
        endEditing(true)
        viewModel.sendMessage(message: typingMessage)
        typingMessage = ""
    }
}

extension View {
    func endEditing(_ force: Bool) {
        UIApplication.shared.windows.forEach { $0.endEditing(force)}
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel(selectedUser: SelectedUser.user1))
}
