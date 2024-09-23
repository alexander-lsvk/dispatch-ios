//
//  WebSocketService.swift
//  DispatchApp
//
//  Created by Alexander Lisovyk on 17.09.24.
//

import Foundation
import SuiKit

final class WebSocketSubscription {
    var webSocketTask: URLSessionWebSocketTask?
    
    // Function to connect to Sui WebSocket and subscribe to events filtered by sender
    func connectAndSubscribe(senderAddress: String) {
        let url = URL(string: "wss://rpc.mainnet.sui.io:443")!
        let request = URLRequest(url: url)
        
        // Create WebSocket task
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Send subscription request
        subscribeToSenderEvents(senderAddress: senderAddress)
        
        // Start receiving messages
        receiveMessages()
    }
    
    // Send subscription request with filter for sender address
    func subscribeToSenderEvents(senderAddress: String) {
        // Create SuiKit EventFilter for the sender address
        let filter = try! EventFilter.init(suiEventFilter: SuiEventFilter.sender(senderAddress))
        
        // Create JSON-RPC message for event subscription
        let subscribeMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "suix_subscribeEvent",
            "params": [
                [
                    "Sender": senderAddress 
                ]
            ]
        ]
        
        do {
            // Serialize the request to JSON data
            let data = try JSONSerialization.data(withJSONObject: subscribeMessage, options: [])
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Error sending subscription request: \(error)")
                } else {
                    print("Subscription request sent for sender: \(senderAddress)")
                }
            }
        } catch {
            print("Error serializing subscription message: \(error)")
        }
    }
    
    // Handle receiving WebSocket messages
    func receiveMessages() {
        webSocketTask?.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleReceivedData(data)
                case .string(let text):
                    print("Received message: \(text)")
                @unknown default:
                    print("Unknown message type received")
                }
                // Continue receiving messages
                self.receiveMessages()
            case .failure(let error):
                print("Error receiving message: \(error)")
            }
        }
    }
    
    // Handle incoming WebSocket data
    func handleReceivedData(_ data: Data) {
        do {
            // Parse the incoming data as JSON
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Received event: \(json)")
                // Process the event data here
            }
        } catch {
            print("Error parsing received data: \(error)")
        }
    }
    
    // Function to disconnect from WebSocket
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

// Usage Example

