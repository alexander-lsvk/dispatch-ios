//
//  MessageView.swift
//  Friday
//
//  Created by Alexander Lisovyk on 12.01.23.
//

import SwiftUI

struct MessageView: View {
    @State var text = ""
    
    var message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 15) {
            if message.user.isCurrentUser {
                Spacer()
            }
            ContentMessageView(
                contentMessage: message.user.name.lowercased() == "Friday AI" ? text : message.content,
                isCurrentUser: message.user.isCurrentUser
            )
        }
    }
}

// MARK: - Preview
struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(message: Message(
            content: "There are a lot of premium iOS templates on iosapptemplates.com",
            user: DataSource.secondUser
        ))
    }
}

extension String {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}
