//
//  OvalTextFieldStyleView.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 06.09.24.
//

import Foundation
import SwiftUI

struct OvalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 20)
            .frame(minHeight: 40)
            .background(Color.receivedMessage)
            .cornerRadius(20)
    }
}
