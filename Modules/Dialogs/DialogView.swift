//
//  DialogView.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 17.09.24.
//

import Foundation

import SwiftUI
import Combine

struct DialogView: View {
    @StateObject var viewModel: DialogViewModel
    
    @State private var showSheet = true
    @State private var showShareSheet = false
    
    @State private var copiedText = "address"
    
    var body: some View {
        NavigationView {
            ZStack {
                if !viewModel.dialogs.isEmpty {
                    ScrollView {
                        VStack {
                            ForEach(viewModel.dialogs, id: \.id) { dialog in
                                withAnimation {
                                    dialogItemView()
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .center, spacing: 0) {
                        Text("No messages")
                            .bold()
                        HStack {
                            Text("Share your address")
                                .font(.system(size: 12, weight: .light))
                                .multilineTextAlignment(.center)
                            
                            Image(systemName: "shareplay")
                                .font(.system(size: 12))
                            
                            Text("or start a conversation")
                                .font(.system(size: 12, weight: .light))
                                .multilineTextAlignment(.center)
                            
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 12))
                        }
                        .padding(.top, 12)
                        
                        Text("if you have the user's address")
                            .font(.system(size: 12, weight: .light))
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .navigationBarTitle("Dispatch", displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showShareSheet.toggle()
                    } label: {
                        Image(systemName: "shareplay")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSheet.toggle()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [viewModel.publicKey ?? ""])
            }
            .sheet(isPresented: $showSheet) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Enter recipient address")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                    
                    TextField("Recipient address...", text: $viewModel.recipientAddress)
                        .font(.system(size: 16))
                        .lineSpacing(6)
                        .textFieldStyle(OvalTextFieldStyle())
                        .frame(minHeight: 40)
                        .padding(16)
                    
                    Button {
                        showSheet.toggle()
                        Task {
                            await viewModel.createDialog()
                        }
                    } label: {
                        Text("Create dialog")
                            .bold()
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.black)
                            .cornerRadius(100)
                            .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                }
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func dialogItemView() -> some View {
        VStack {
            VStack {
                Text("0x030")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("How was it?")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            
            Divider()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }
}

// MARK: - UIActivityController

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    DialogView(viewModel: DialogViewModel())
}
