import Foundation
import Security

protocol MonobankTokenStore {
  func saveToken(_ token: String) throws
  func loadToken() throws -> String?
  func deleteToken() throws
}

final class MonobankKeychainStore: MonobankTokenStore {
  static let shared = MonobankKeychainStore()

  private let service = "com.shoode.calendar.monobank"
  private let account = "personal-token"

  private init() {}

  func saveToken(_ token: String) throws {
    let data = Data(token.utf8)
    try deleteToken()

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw MonobankSecurityError.keychainSaveFailed(status)
    }
  }

  func loadToken() throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    if status == errSecItemNotFound {
      return nil
    }

    guard status == errSecSuccess else {
      throw MonobankSecurityError.keychainReadFailed(status)
    }

    guard let data = item as? Data,
      let token = String(data: data, encoding: .utf8)
    else {
      throw MonobankSecurityError.invalidTokenData
    }

    return token
  }

  func deleteToken() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw MonobankSecurityError.keychainDeleteFailed(status)
    }
  }
}

enum MonobankSecurityError: LocalizedError {
  case keychainSaveFailed(OSStatus)
  case keychainReadFailed(OSStatus)
  case keychainDeleteFailed(OSStatus)
  case invalidTokenData

  var errorDescription: String? {
    switch self {
    case .keychainSaveFailed(let status):
      return "Failed to save Monobank token (\(status))."
    case .keychainReadFailed(let status):
      return "Failed to read Monobank token (\(status))."
    case .keychainDeleteFailed(let status):
      return "Failed to delete Monobank token (\(status))."
    case .invalidTokenData:
      return "Monobank token data is invalid."
    }
  }
}
