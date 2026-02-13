import Flutter
import UIKit
import HealthKit

var _hostApi : FlutterMindfulMinutesHostApi? = nil

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
  
  func isAvailable(completion: @escaping (Result<Bool, any Error>) -> Void) {
    completion(.success(HKHealthStore.isHealthDataAvailable()))
  }
  
  func hasPermission(completion: @escaping (Result<Bool, any Error>) -> Void) {
    // Check if HealthKit is available
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 6, userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device."])) )
      return
    }

    // Get the mindful session type
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable."])) )
      return
    }

    // Check authorization status for writing (sharing) mindful minutes
    let healthStore = HKHealthStore()
    let status = healthStore.authorizationStatus(for: mindfulType)

    switch status {
    case .sharingAuthorized:
      completion(.success(true))
    case .sharingDenied:
      completion(.success(false))
    case .notDetermined:
      completion(.success(false))
    @unknown default:
      completion(.success(false))
    }
  }
  
  func requestPermission(completion: @escaping (Result<Bool, any Error>) -> Void) {
    // Request authorization to write Mindful Minutes (mindfulSession) to HealthKit
    let healthStore = HKHealthStore()

    // Ensure HealthKit is available on this device
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device."])) )
      return
    }

    // Define the types we want to share (write) and optionally read
    guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mindful Session type is unavailable."])) )
      return
    }

    let toShare: Set<HKSampleType> = [mindfulType]
    let toRead: Set<HKObjectType> = [mindfulType]

    healthStore.requestAuthorization(toShare: toShare, read: toRead) { success, error in
      if let error = error {
        completion(.failure(error))
        return
      }
      completion(.success(success))
    }
  }
  
  func writeMindfulMinutes(startSeconds: Int64, endSeconds: Int64, completion: @escaping (Result<Bool, any Error>) -> Void) {
    let healthStore = HKHealthStore()

    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(NSError(domain: "FlutterMindfulMinutes", code: 3, userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device."])) )
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
        completion(.failure(error))
        return
      }
      completion(.success(success))
    }
  }
  
}
