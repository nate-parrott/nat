import Foundation
import CommonCrypto

extension Data {
    /// Returns a SHA256 hash of the data as a hex string
    var sha256Hash: String {
        // Create an array to store the hash output
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        // Calculate the hash
        self.withUnsafeBytes { bufferPtr in
            _ = CC_SHA256(bufferPtr.baseAddress, CC_LONG(self.count), &hash)
        }
        
        // Convert the hash to a hex string
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}