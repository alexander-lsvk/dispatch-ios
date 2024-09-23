//
//  DispatchAppApp.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 06.09.24.
//

import SwiftUI

@main
struct DispatchAppApp: App {
    var body: some Scene {
        WindowGroup {
            DialogView(viewModel: DialogViewModel())
        }
    }
}
