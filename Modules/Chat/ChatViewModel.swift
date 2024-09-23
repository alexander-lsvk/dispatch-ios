//
//  ChatViewModel.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 06.09.24.
//

import Foundation
import Combine
import SwiftUI
import StoreKit
import CryptoKit
import CommonCrypto
import CryptoSwift
import TweetNacl

import SuiKit
import KeychainSwift
import Blake2
import Sodium

struct MessageB: Codable {
    let sender: String
    let timestamp: String
    let content: String // [UInt8]
}

struct MessagesResponse: Codable {
    let dialogHash: [UInt8]
    let messages: [MessageB]
}

struct ChatCountsResponse: Codable {
    let address: String
    let count: String
}

struct Connection: ConnectionProtocol {
    var fullNode: String
    var websocket: String?
    var graphql: String?
}

enum SelectedUser {
    case user1
    case user2
}

final class ChatViewModel: ObservableObject {
    @Published var sendButtonActive = true
    @Published var showSubscription = false
    @Published var showRateApp = false
    @Published var showFirstSubscription = false
    @Published var showOnboarding = false
    
    @Published var publicKey: String?
    @Published var messages = [Message]()
    
    private let currentUser = User(name: "Anonym", avatar: "", isCurrentUser: true)
    private let fridayUser = User(name: "Friday AI", avatar: "wilson", isCurrentUser: false)
    
    private var wallet: Wallet?
    private var account: Account?
    
    private let contractAddress = "0xc7987d777040a0a8a0d62cf8821bf662ea66076372432f64692f13f16be51960"
    private let objectAddress = "0x102a9cb98cb89ff75d248faeb6b4409fbe456f5adda9f14992765d7b86eed000"
    private let sponsorAddress = "0x8f686fb693230f329e6f7a833d3ae7c985c291559923dd15d48d7a86749bc548"
    private var gasObject = "0x2abcd19fb332a338b9782c89aa21eb6cb84775dca409cd3bc98b5ce374008963"
    
    var recepientAddress = "0x2686b25b45119f869f5c1df15d198d181e395b68bb35f12c3417371e9e3dfabb"
    
    let selectedUser: SelectedUser
    let provider = SuiProvider(connection: Connection(fullNode: "https://fullnode.mainnet.sui.io:443", websocket: "wss://fullnode.mainnet.sui.io:443"))
    
    private var timer: Timer?
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(selectedUser: SelectedUser) {
        self.selectedUser = selectedUser
    }
    
    @objc
    func fetchMessages() {
        Task {
            try? await getLastNMessages()
        }
    }
    
    func onAppear() {
        try? handleWallet()
        
        fetchMessages()
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(fetchMessages), userInfo: nil, repeats: true)
    }
    
    func sendMessage(message: String) {
        Task {
            try await sendBlockMessage(message: message)
        }
    }
}


// MARK: - Private functions
extension ChatViewModel {
    func handleWallet() throws {
        let keychain = KeychainSwift()
        
        
//        if selectedUser == .user1 {
//            let mnemonics = "write own mass soup helmet plunge illness physical trial chat august cry"
//            recepientAddress = "0x28040bba2a0bbde55dfb0302470159a7c794b96f7f1433a537651729ab28101c"
//            self.account = try Account(mnemonics, accountType: .ed25519)
//            self.publicKey = try account?.publicKey.toSuiAddress()
//        } else {
//            let mnemonics = "original pluck lobster evidence media head adjust game ignore bracket virus absent"
//            recepientAddress = "0x2686b25b45119f869f5c1df15d198d181e395b68bb35f12c3417371e9e3dfabb"
//            self.account = try Account(mnemonics, accountType: .ed25519)
//            self.publicKey = try account?.publicKey.toSuiAddress()
//        }
//        
//        let mnemonics2 = "original pluck lobster evidence media head adjust game ignore bracket virus absent"
//        let account2 = try Account(mnemonics2, accountType: .ed25519)

//        let res = convertAndPerformKeyAgreement(
//            aliceEd25519PublicKey: try account!.publicKey.base64(),
//            aliceEd25519PrivateKey: (try account?.export().privateKey)!,
//            bobEd25519PublicKey: try account2.publicKey.base64(),
//            bobEd25519PrivateKey: (try account2.export().privateKey)
//        )
//        print(res)
        
        if let mnemonic = keychain.get("mnemonic"), let privateKey = keychain.get("privateKey") {
            do {
                self.wallet = try Wallet(mnemonicString: mnemonic)
                account = wallet?.accounts.first
                let publicKey = try! wallet?.accounts.first?.publicKey.toSuiAddress()
                self.publicKey = publicKey
                print("Restored PK: \(publicKey ?? "")")
            }
        } else {
            let wallet = try Wallet()
            self.wallet = wallet
            account = wallet.accounts.first
            keychain.set(wallet.mnemonic.mnemonic().joined(separator: " "), forKey: "mnemonic")
            do {
                keychain.set(try wallet.accounts.first!.export().privateKey, forKey: "privateKey")
                keychain.set(try wallet.accounts.first!.publicKey.toSuiAddress(), forKey: "publicKey")
            }
            print("Generated PK: \(try! wallet.accounts.first?.publicKey.toSuiAddress() ?? "")")
        }
    }
    
    func calculateDialogId(senderPublicKey: String, recepientPublicKey: String) -> String {
        let sortedKeys = [senderPublicKey, recepientPublicKey].sorted()
        
        let combinedString = sortedKeys.joined()
        let combinedData = Data(combinedString.utf8)

        let data = Data(combinedData.sha3(.sha256))

        let hashString = data.map { String(format: "%02x", $0) }.joined()

        return hashString
    }

    func convertEd25519PrivateKeyToX25519(ed25519PrivateKey: Data) -> Curve25519.KeyAgreement.PrivateKey? {
        guard ed25519PrivateKey.count == 32 else { return nil }
        
        let h = SHA512.hash(data: ed25519PrivateKey)
        var x25519PrivateKey = Data(h.prefix(32))
        x25519PrivateKey[0] &= 248
        x25519PrivateKey[31] &= 127
        x25519PrivateKey[31] |= 64
        
        return try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: x25519PrivateKey)
    }

    func convertEd25519PublicKeyToX25519(ed25519PublicKey: Data) -> Curve25519.KeyAgreement.PublicKey? {
        guard ed25519PublicKey.count == 32 else { return nil }

        var x25519PublicKey = Data(ed25519PublicKey)
        x25519PublicKey[31] &= 127
        
        return try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: x25519PublicKey)
    }

    func generateSymmetricKey(privateKey: Curve25519.KeyAgreement.PrivateKey, publicKey: Curve25519.KeyAgreement.PublicKey) -> SymmetricKey? {
        guard let sharedSecret = try? privateKey.sharedSecretFromKeyAgreement(with: publicKey) else {
            return nil
        }
        
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "Salt".data(using: .utf8)!,
            sharedInfo: "Info".data(using: .utf8)!,
            outputByteCount: 32
        )
    }

    func convertAndPerformKeyAgreement(aliceEd25519PublicKey: String, aliceEd25519PrivateKey: String,
                                       bobEd25519PublicKey: String, bobEd25519PrivateKey: String) -> (aliceSymmetricKey: String, bobSymmetricKey: String)? {
        guard let alicePublicKeyData = Data(base64Encoded: aliceEd25519PublicKey),
              let alicePrivateKeyData = Data(base64Encoded: aliceEd25519PrivateKey),
              let bobPublicKeyData = Data(base64Encoded: bobEd25519PublicKey),
              let bobPrivateKeyData = Data(base64Encoded: bobEd25519PrivateKey) else {
            print("Failed to decode base64 keys")
            return nil
        }
        
        guard let aliceX25519PrivateKey = convertEd25519PrivateKeyToX25519(ed25519PrivateKey: alicePrivateKeyData),
              let aliceX25519PublicKey = convertEd25519PublicKeyToX25519(ed25519PublicKey: alicePublicKeyData),
              let bobX25519PrivateKey = convertEd25519PrivateKeyToX25519(ed25519PrivateKey: bobPrivateKeyData),
              let bobX25519PublicKey = convertEd25519PublicKeyToX25519(ed25519PublicKey: bobPublicKeyData) else {
            print("Failed to convert Ed25519 keys to X25519")
            return nil
        }
        
        guard let aliceSymmetricKey = generateSymmetricKey(privateKey: aliceX25519PrivateKey, publicKey: bobX25519PublicKey),
              let bobSymmetricKey = generateSymmetricKey(privateKey: bobX25519PrivateKey, publicKey: aliceX25519PublicKey) else {
            print("Failed to generate symmetric keys")
            return nil
        }
        
        return (
            aliceSymmetricKey: aliceSymmetricKey.withUnsafeBytes { Data($0).base64EncodedString() },
            bobSymmetricKey: bobSymmetricKey.withUnsafeBytes { Data($0).base64EncodedString() }
        )
    }
    
    func sendBlockMessage(message: String) async throws {
        do {
            var tx = try TransactionBlock()

            let privateKey = try account?.export().privateKey

            let dialogId = calculateDialogId(senderPublicKey: (try account?.publicKey.toSuiAddress())!, recepientPublicKey: recepientAddress)
            print("dialog hash: \(dialogId)")
            _ = try tx.moveCall(
                target: "\(contractAddress)::dialog_management::send_message",
                arguments: [
                    try tx.object(id: objectAddress).toTransactionArgument(),
                    .input(try tx.pure(value: .string(dialogId))),
                    .input(try tx.pure(value: .string(message)))
                ]
            )

            try tx.setSender(sender: (account?.publicKey.toSuiAddress())!)
            try tx.setGasOwner(owner: sponsorAddress)

            let gasObjectDetails = try await provider.getObject(objectId: gasObject, options: SuiObjectDataOptions(showContent: true))

            guard let gasData = gasObjectDetails?.data else {
                throw NSError(domain: "com.yourapp.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch gas object details"])
            }

            let gasPayment = SuiObjectRef(
                objectId: gasData.objectId,
                version: gasData.version,
                digest: TransactionDigest(gasData.digest)
            )

            try tx.setGasPayment(payments: [gasPayment])
            tx.setGasBudget(price: 10000000)

            let signer = RawSigner(account: account!, provider: provider)
            let signedTxBySender = try await signer.signTransactionBlock(transactionBlock: &tx)

            let requestBody: [String: Any] = [
                "senderSignedTx": [
                    "bytes": signedTxBySender.transactionBlockBytes,
                    "signature": signedTxBySender.signature
                ]
            ]
            
            // Serialize the requestBody to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            
            // Prepare the URL request
            var request = URLRequest(url: URL(string: "http://localhost:3000/sponsor-transaction")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Use async/await URLSession for the request
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            // Check the response status code
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Transaction sent successfully.")
            } else {
                print("Failed to send transaction. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            //try await getLastNMessages()
        } catch {
            print(error)
        }
    }
    
    func getLastNMessages() async throws {
        do {
            var tx = try TransactionBlock()

            let dialogHash = calculateDialogId(senderPublicKey: (try account?.publicKey.toSuiAddress())!, recepientPublicKey: recepientAddress)
            print("Dialog hash: \(dialogHash)")

            _ = try tx.moveCall(
                target: "\(contractAddress)::dialog_management::get_last_n_messages",
                arguments: [
                    try tx.object(id: objectAddress).toTransactionArgument(),
                    .input(try tx.pure(value: .string(dialogHash))),
                    .input(try tx.pure(value: .number(100)))
                ]
            )
            
            let signer = account!
            
            let executeResult = try await provider.devInspectTransactionBlock(transactionBlock: &tx, sender: signer)
            
            print("Events 2: \(executeResult!.events)")
            
            let parsedJson = executeResult?.events.first?.parsedJson
            
            if let parsedJson = try? parsedJson?.rawData() {

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let messagesResponse = try decoder.decode(MessagesResponse.self, from: parsedJson)
                DispatchQueue.main.async {
                    let account = try! self.account?.publicKey.toSuiAddress()
                    self.messages = messagesResponse.messages.map { message in
//                        let contentData = Data(message.content)
//                        let decodedString = String(data: contentData, encoding: .utf8)
                        return Message(content: message.content, user: (message.sender == account) ? DataSource.secondUser : DataSource.firstUser)
                    }
                }
                print("Messages: \(messagesResponse.messages)")
                
            } else {
                print("Failed to convert SwiftyJSON object to Data")
            }
        } catch {
            print(error)
        }
    }
}
