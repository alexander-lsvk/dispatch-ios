//
//  ChooseAccountView.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 08.09.24.
//

import Foundation
import SwiftUI

struct ChooseAccountView: View {
    @State var presentChatUser1 = false
    @State var presentChatUser2 = false
    
    var body: some View {
        VStack {
            Spacer()
            Button {
                presentChatUser1.toggle()
            } label: {
                Text("Login as User-1")
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue)
                    .cornerRadius(20)
            }
            
            Button {
                presentChatUser2.toggle()
            } label: {
                Text("Login as User-2")
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue)
                    .cornerRadius(20)
            }
            Spacer()
        }
        .fullScreenCover(isPresented: $presentChatUser1) {
            ChatView(viewModel: ChatViewModel(selectedUser: .user1))
        }
        .fullScreenCover(isPresented: $presentChatUser2) {
            ChatView(viewModel: ChatViewModel(selectedUser: .user2))
        }
    }
}

#Preview {
    ChooseAccountView()
}
