//
//  ContentMessageView.swift
//  Friday
//
//  Created by Alexander Lisovyk on 12.01.23.
//

import SwiftUI

struct ContentMessageView: View {
    var contentMessage: String
    var isCurrentUser: Bool
    
    var body: some View {
        Text(contentMessage)
            .padding(10)
            .font(.system(size: 16))
            .lineSpacing(6)
            .foregroundColor(isCurrentUser ? .white : Color.black)
            .background(isCurrentUser ? Color.sentMessage : Color.receivedMessage)
            .cornerRadius(10)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = contentMessage
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }
}

// MARK: - Preview
struct ContentMessageView_Previews: PreviewProvider {
    static var previews: some View {
        ContentMessageView(contentMessage: "wilson.loading", isCurrentUser: false)
    }
}
