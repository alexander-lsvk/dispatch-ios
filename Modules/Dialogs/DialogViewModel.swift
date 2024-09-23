//
//  DialogViewModel.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 17.09.24.
//

import Foundation
import KeychainSwift
import SuiKit
import Bip39

struct Dialog {
    let id: String
}

final class DialogViewModel: ObservableObject {
    @Published var dialogs = [Dialog]()
    @Published var publicKey: String?
    
    @Published var recipientAddress = "0x2686b25b45119f869f5c1df15d198d181e395b68bb35f12c3417371e9e3dfabb"
    
    private var wallet: Wallet?
    private var account: Account?

    private let packageAddress = "0x69f4f7198d1222088ef6702edc169e519317ba9fc9c3fb43172e908d1bdee2ab"
    private let dialogsObjectAddress = "0x49e324b947f31cb234fcab4dd8cbc7ec9795ba6ca388b434f981cc8d6c87f446"
    private let chatsObjectAddress = "0x760c7faa20d36f02df369b53592f83a8124dfe7092e2299325b3bf014286cc80"
    private let sponsorAddress = "0x8f686fb693230f329e6f7a833d3ae7c985c291559923dd15d48d7a86749bc548"
    private var gasObjectAddress = "0x2abcd19fb332a338b9782c89aa21eb6cb84775dca409cd3bc98b5ce374008963"
    
    private let provider = SuiProvider(connection: Connection(fullNode: "https://fullnode.mainnet.sui.io:443", websocket: "wss://rpc.mainnet.sui.io:443"))
    
    func onAppear() {
        Task {
            try? await handleWallet()
        }
    }
    
    func createDialog() async {
        if let mnemonic = wallet?.mnemonic, let newDialogAccount = try? generateNewDialogAccount(mnemonic: mnemonic) {
            try? await sendWelcomeMessage(account: newDialogAccount)
        }
    }
}

// MARK: - Private functions

extension DialogViewModel {
    private func handleWallet() async throws {
        let keychain = KeychainSwift()

        if let mnemonic = keychain.get("mnemonic") {
            do {
                let wallet = try Wallet(mnemonicString: mnemonic)
                self.wallet = wallet
                guard let address = try wallet.accounts.first?.publicKey.toSuiAddress() else {
                    return
                }
                let chatsCount = await getChatCounts(address: address)
                let accounts = try Array(0...chatsCount).map { try createDialogAccount(mnemonic: Mnemonic(mnemonic: mnemonic.components(separatedBy: " ")), accountNumber: $0) }
                self.wallet?.accounts = accounts
                print("Restored accounts: \(wallet.accounts.compactMap { try? $0.publicKey.toSuiAddress() }.joined(separator: ", "))")
            }
        } else {
            let wallet = try Wallet()
            self.wallet = wallet
            keychain.set(wallet.mnemonic.mnemonic().joined(separator: " "), forKey: "mnemonic")
            print("Generated wallet (accounts): \(wallet.accounts.compactMap { try? $0.publicKey.toSuiAddress() }.joined(separator: ", "))")
        }
        
        if let wallet {
            DispatchQueue.main.async {
                self.dialogs = wallet.accounts.dropFirst().compactMap { Dialog(id: try! $0.publicKey.toSuiAddress()) }
            }
        }
    }
    
    private func generateNewDialogAccount(mnemonic: Mnemonic) throws -> Account? {
        guard let accountsNumber = wallet?.accounts.count else {
            return nil
        }
        let account = try createDialogAccount(mnemonic: mnemonic, accountNumber: accountsNumber)
        wallet?.accounts.append(account)
        return account
    }
    
    private func createDialogAccount(mnemonic: Mnemonic, accountNumber: Int) throws -> Account {
        let privateKey = try ED25519PrivateKey(mnemonic.mnemonic().joined(separator: " "), "m/44'/784'/0'/0'/\(accountNumber)'")
        let account = try Account(privateKey: privateKey)
        return account
    }
    
    private func sendWelcomeMessage(account: Account, message: String = "Hi") async throws {
        do {
            var transaction = try TransactionBlock()

            let privateKey = try account.export().privateKey

            let senderAddress = try account.publicKey.toSuiAddress()
            let dialogHash = calculateDialogHash(senderAddress, recipientAddress)

            print("Created dialog hash: \(dialogHash)")
            
            _ = try transaction.moveCall(
                target: "\(packageAddress)::dialog_management::send_message",
                arguments: [
                    try transaction.object(id: dialogsObjectAddress).toTransactionArgument(),
                    .input(try transaction.pure(value: .string(dialogHash))),
                    .input(try transaction.pure(value: .string(message)))
                ]
            )

            try transaction.setSender(sender: account.publicKey.toSuiAddress())
            try transaction.setGasOwner(owner: sponsorAddress)

            let gasObjectDetails = try await provider.getObject(objectId: gasObjectAddress, options: SuiObjectDataOptions(showContent: true))

            guard let gasData = gasObjectDetails?.data else {
                throw NSError(domain: "com.yourapp.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch gas object details"])
            }

            let gasPayment = SuiObjectRef(
                objectId: gasData.objectId,
                version: gasData.version,
                digest: TransactionDigest(gasData.digest)
            )

            try transaction.setGasPayment(payments: [gasPayment])
            transaction.setGasBudget(price: 10000000)

            let signer = RawSigner(account: account, provider: provider)
            let senderSignedTransaction = try await signer.signTransactionBlock(transactionBlock: &transaction)

            let requestBody: [String: Any] = [
                "senderSignedTx": [
                    "bytes": senderSignedTransaction.transactionBlockBytes,
                    "signature": senderSignedTransaction.signature
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            var request = URLRequest(url: URL(string: "http://localhost:3000/sponsor-transaction")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Transaction sent successfully.")
                
                if let mainAccount = wallet?.accounts.first {
                    await updateDialogChatCount(account: mainAccount)
                }
            } else {
                print("Failed to send transaction. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print(error)
        }
    }

    private func getChatCounts(address: String) async -> Int {
        do {
            var transaction = try TransactionBlock()
            
            _ = try transaction.moveCall(
                target: "\(packageAddress)::dialog_management::get_chat_count",
                arguments: [
                    try transaction.object(id: chatsObjectAddress).toTransactionArgument(),
                    .input(try transaction.pure(value: .address(AccountAddress.fromHex(address))))
                ]
            )
            
            guard let signer = wallet?.accounts.first else {
                return 0
            }
            
            let executeResult = try await provider.devInspectTransactionBlock(transactionBlock: &transaction, sender: signer)
            
            print("Events 2: \(executeResult!.events)")
            
            let parsedJson = executeResult?.events.first?.parsedJson
            
            if let parsedJson = try? parsedJson?.rawData() {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let chatCountsResponse = try decoder.decode(ChatCountsResponse.self, from: parsedJson)
                
                print("Messages: \(chatCountsResponse.count)")
                return Int(chatCountsResponse.count) ?? 0
                
            } else {
                print("Failed to convert SwiftyJSON object to Data")
                return 0
            }
        } catch {
            print(error)
            return 0
        }
    }
    
    private func updateDialogChatCount(account: Account) async {
        do {
            var transaction = try TransactionBlock()

            _ = try transaction.moveCall(
                target: "\(packageAddress)::dialog_management::update_chat_count",
                arguments: [
                    try transaction.object(id: chatsObjectAddress).toTransactionArgument(),
                    .input(try transaction.pure(value: .address(AccountAddress.fromHex(account.publicKey.toSuiAddress()))))
                ]
            )

            try transaction.setSender(sender: account.publicKey.toSuiAddress())
            try transaction.setGasOwner(owner: sponsorAddress)

            let gasObjectDetails = try await provider.getObject(objectId: gasObjectAddress, options: SuiObjectDataOptions(showContent: true))

            guard let gasData = gasObjectDetails?.data else {
                throw NSError(domain: "com.yourapp.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch gas object details"])
            }

            let gasPayment = SuiObjectRef(
                objectId: gasData.objectId,
                version: gasData.version,
                digest: TransactionDigest(gasData.digest)
            )

            try transaction.setGasPayment(payments: [gasPayment])
            transaction.setGasBudget(price: 10000000)

            let signer = RawSigner(account: account, provider: provider)
            let senderSignedTransaction = try await signer.signTransactionBlock(transactionBlock: &transaction)

            let requestBody: [String: Any] = [
                "senderSignedTx": [
                    "bytes": senderSignedTransaction.transactionBlockBytes,
                    "signature": senderSignedTransaction.signature
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            var request = URLRequest(url: URL(string: "http://localhost:3000/sponsor-transaction")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Chat count transaction sent successfully.")
            } else {
                print("Failed to send transaction. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                await updateDialogChatCount(account: account)
            }
        } catch {
            print(error)
        }
    }
    
    private func calculateDialogHash(_ senderAddress: String, _ recepientAddress: String) -> String {
        let sortedKeys = [senderAddress, recepientAddress].sorted()
        
        let combinedString = sortedKeys.joined()
        let combinedData = Data(combinedString.utf8)

        let data = Data(combinedData.sha3(.sha256))
        let hashString = data.map { String(format: "%02x", $0) }.joined()

        return hashString
    }
}
