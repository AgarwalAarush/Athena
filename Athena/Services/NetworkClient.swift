//
//  NetworkClient.swift
//  Athena
//
//  Created by Cursor on 10/30/25.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(statusCode: Int, message: String)
    case networkError(Error)
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}

class NetworkClient {
    static let shared = NetworkClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    // MARK: - Generic Request Methods
    
    func request<T: Decodable>(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkError(NSError(domain: "Invalid response", code: -1))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            return try decoder.decode(T.self, from: data)
            
        } catch let error as NetworkError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw NetworkError.cancelled
            } else if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkError.timeout
            } else {
                throw NetworkError.networkError(error)
            }
        }
    }
    
    func post<Request: Encodable, Response: Decodable>(
        url: URL,
        body: Request,
        headers: [String: String]? = nil
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await request(url: url, method: .post, headers: headers, body: bodyData)
    }
    
    // MARK: - Streaming
    
    func streamRequest(
        url: URL,
        method: HTTPMethod = .post,
        headers: [String: String]? = nil,
        body: Data? = nil,
        onChunk: @escaping (String) -> Void
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (asyncBytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.networkError(NSError(domain: "Invalid response", code: -1))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: "Streaming failed")
        }
        
        var buffer = ""
        
        for try await byte in asyncBytes {
            if let char = String(bytes: [byte], encoding: .utf8) {
                buffer.append(char)
                
                // Process complete SSE messages
                if buffer.hasSuffix("\n\n") {
                    let lines = buffer.split(separator: "\n")
                    
                    for line in lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data != "[DONE]" {
                                onChunk(data)
                            }
                        }
                    }
                    
                    buffer = ""
                }
            }
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

