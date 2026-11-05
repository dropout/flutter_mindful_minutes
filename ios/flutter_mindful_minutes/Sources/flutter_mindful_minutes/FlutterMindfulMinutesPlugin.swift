import Flutter
import UIKit
import HealthKit
import Logging
import SwiftUI



var _hostApi : FlutterMindfulMinutesHostApi? = nil

/// Error codes sent to the Dart side, they have to match `MindfulMinutesErrorCodes` in Dart.
enum ErrorCodes {
  static let healthDataUnavailable = "health_data_unavailable"
  static let mindfulnessNotSupported = "mindfulness_not_supported"
  static let missingEntitlement = "missing_entitlement"
}

/// Converts known HealthKit errors to `PigeonError`s with a stable code,
/// so the Dart side can throw a typed exception. Other errors are returned unchanged.
func mapHealthKitError(_ error: Error) -> Error {
  let nsError = error as NSError
  let details: [String: Any] = [
    "domain": nsError.domain,
    "code": nsError.code,
    "description": nsError.localizedDescription,
  ]

  // HealthKit reports a missing entitlement as `errorAuthorizationDenied` (code 4)
  // with the entitlement name in the description, there is no dedicated error code.
  if nsError.domain == HKErrorDomain,
     nsError.code == HKError.Code.errorAuthorizationDenied.rawValue,
     nsError.localizedDescription.contains("com.apple.developer.healthkit") {
    return PigeonError(
      code: ErrorCodes.missingEntitlement,
      message: "Missing com.apple.developer.healthkit entitlement. Enable the HealthKit capability for your app target in Xcode (Signing & Capabilities).",
      details: details
    )
  }

  return error
}

public class FlutterMindfulMinutesPlugin: NSObject, FlutterPlugin {
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    
    // Setup method calls api
    _hostApi = FlutterMindfulMinutesHostApiImpl()
    FlutterMindfulMinutesHostApiSetup.setUp(binaryMessenger: messenger, api: _hostApi)
    
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    _hostApi = nil
  }
  
}

class FlutterMindfulMinutesHostApiImpl : FlutterMindfulMinutesHostApi {
  
  let logger: Logger
  
  init() {
    var logger = Logger(label: "FlutterMindfulMinutesHostApiImpl")
    #if DEBUG
    logger.logLevel = .debug
    #endif    
    self.logger = logger
  }
  
  func checkAvailability(completion: @escaping (Result<Void, any Error>) -> Void) {
    logger.debug("Checking if HealthKit is available")
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(PigeonError(code: ErrorCodes.healthDataUnavailable, message: "Health data is not available on this device.", details: nil)))
      return
    }
    guard HKObjectType.categoryType(forIdentifier: .mindfulSession) != nil else {
      completion(.failure(PigeonError(code: ErrorCodes.mindfulnessNotSupported, message: "Mindful Session type is unavailable on this device.", details: nil)))
      return
    }
    completion(.success(()))
  }
  
  func getAuthorizationStatus(completion: @escaping (Result<AuthorizationStatus, any Error>) -> Void) {
    logger.debug("Getting authorization status")
    
    // Check if HealthKit is available
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(PigeonError(code: ErrorCodes.healthDataUnavailable, message: "Health data is not available on this device, cannot check authorization for writing mindful minutes.", details: nil)) )
      return
    }

    // Get the mindful session type
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable, cannot check authorization for writing mindful minutes."])) )
      return
    }

    // Check authorization status for writing (sharing) mindful minutes
    // For reading status cannot be determined because of privacy policies
    let healthStore = HKHealthStore()
    let status = healthStore.authorizationStatus(for: mindfulType)
    
    
    logger.debug("Authorization status: \(status)")
    switch status {
      case .sharingAuthorized:
        completion(.success(.authorized))
      break
      case .sharingDenied:
        completion(.success(.denied))
      break
      case .notDetermined:
        completion(.success(.notDetermined))
      break
      @unknown default:
        completion(.success(.unknown))
      break
    }
  }
  
  func getRequestForAuthorizationStatus(completion: @escaping (Result<RequestStatusForAuthorization, Error>) -> Void) {
    logger.debug("Getting status for the request")
    
    // Check if HealthKit is available
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(PigeonError(code: ErrorCodes.healthDataUnavailable, message: "Health data is not available on this device, cannot check authorization for writing mindful minutes.", details: nil)) )
      return
    }

    // Get the mindful session type
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable, cannot check authorization for writing mindful minutes."])) )
      return
    }
    
    let healthStore = HKHealthStore()
    healthStore.getRequestStatusForAuthorization(toShare: [mindfulType], read: [mindfulType]) { (status, error) in
      if let error = error {
        completion(.failure(mapHealthKitError(error)))
      } else {
        switch status {
          case .shouldRequest:
            completion(.success(.shouldRequest))
          break
          case .unnecessary:
            completion(.success(.unnecessary))
          break
          case .unknown:
            completion(.success(.unknown))
          break
          @unknown default:
            completion(.success(.unknown))
          break
        }
      }
    }
  }
  
  func requestAuthorization(completion: @escaping (Result<Bool, any Error>) -> Void) {
    logger.debug("Requesting authorization")
    // Request authorization to write Mindful Minutes (mindfulSession) to HealthKit
    let healthStore = HKHealthStore()

    // Ensure HealthKit is available on this device
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(PigeonError(code: ErrorCodes.healthDataUnavailable, message: "Health data is not available on this device.", details: nil)) )
      return
    }

    // Define the types we want to share (write) and optionally read
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable."])) )
      return
    }

    let toShare: Set<HKSampleType> = [mindfulType]
    let toRead: Set<HKObjectType> = [mindfulType]
          
    // Success in .requestAuthorization only indicates wheter the sheet have been presented or not
    healthStore.requestAuthorization(toShare: toShare, read: toRead) { success, error in
      if let error = error {
        completion(.failure(mapHealthKitError(error)))
        return
      }
      completion(.success(success))
      self.logger.debug("Authorization request complete with result: \(success)")
    }
  }
  
  func writeMindfulMinutes(startSeconds: Int64, endSeconds: Int64, completion: @escaping (Result<Bool, any Error>) -> Void) {
    let healthStore = HKHealthStore()

    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(PigeonError(code: ErrorCodes.healthDataUnavailable, message: "Health data is not available on this device.", details: nil)) )
      return
    }

    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable."])) )
      return
    }

    // Convert milliseconds to Date
    let startDate = Date(timeIntervalSince1970: TimeInterval(startSeconds))
    let endDate = Date(timeIntervalSince1970: TimeInterval(endSeconds))

    // Validate dates
    guard endDate > startDate else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 5, userInfo: [NSLocalizedDescriptionKey: "End date must be later than start date."])) )
      return
    }

    let sample = HKCategorySample(type: mindfulType, value: 0, start: startDate, end: endDate)

    healthStore.save(sample) { success, error in
      if let error = error {
        completion(.failure(mapHealthKitError(error)))
        return
      }
      completion(.success(success))
    }
  }
  
}
