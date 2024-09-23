//
//  MessengerViewModel.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 11.09.24.
//

import Foundation
import SuiKit

class DialogManager {
    private let client: SuiProvider
    private let sponsorKeyPair: Account
    private let userDialogsId = "0xe607dc4a0e3c0d303d217871232d1b214c873e0e6989017dcedbf15094c60a59"
    private var dialogKey: Account
    
    init(client: SuiProvider = SuiProvider(connection: Connection(fullNode: "https://fullnode.mainnet.sui.io:443"))) throws {
        self.client = client
        
        let mnemonics = "close bundle market fresh add spawn eyebrow ignore guess exile runway chuckle"
        self.sponsorKeyPair = try Account(mnemonics, accountType: .ed25519)
        
        self.dialogKey = try Wallet().accounts.first!
    }
    
    func createAndExecuteSponsoredTransaction2() async throws {
        let txb = try TransactionBlock()
        _ = try txb.moveCall(
            target: "0xffe6cd362816273ea4f0f64fa030b511fb67fd14c9d5fb77b33674fe2f20caea::dialog_management::create_dialog",
            arguments: [
                try txb.object(id: "0xe607dc4a0e3c0d303d217871232d1b214c873e0e6989017dcedbf15094c60a59").toTransactionArgument()
            ]
        )
        try txb.setSender(sender: try sponsorKeyPair.publicKey.toSuiAddress())
        try txb.setGasOwner(owner: try sponsorKeyPair.publicKey.toSuiAddress())
        txb.setGasBudget(price: 2_000_000)
        
        let builtTx = try await txb.build(client, true)
        
        let sponsorSignature = try sponsorKeyPair.sign(builtTx)
        let userSignature = try dialogKey.sign(builtTx)
        
        let result = try await client.executeTransactionBlock(
            transactionBlock: builtTx.base64EncodedString(),
            signature: sponsorSignature.hex() + userSignature.hex()
        )
        print("Transaction result: \(result)")
    }
    
    func combineSignatures(sponsorSignature: Data, userSignature: Data, sponsorPublicKey: String, userPublicKey: String) -> String {
        let sponsorSigHex = sponsorSignature.hexEncodedString()
        let userSigHex = userSignature.hexEncodedString()
        
        let sponsorPubKey = sponsorPublicKey.starts(with: "0x") ? String(sponsorPublicKey.dropFirst(2)) : sponsorPublicKey
        let userPubKey = userPublicKey.starts(with: "0x") ? String(userPublicKey.dropFirst(2)) : userPublicKey
        
        return "\(sponsorSigHex)\(userSigHex)"
    }
}
