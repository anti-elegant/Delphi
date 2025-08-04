import Foundation
import SwiftData
import UserNotifications

// MARK: - Notification Service Error Types
enum NotificationServiceError: LocalizedError {
  case permissionDenied
  case schedulingFailed(Error)
  case invalidPrediction

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      return "Notification permission denied"
    case .schedulingFailed(let error):
      return "Failed to schedule notification: \(error.localizedDescription)"
    case .invalidPrediction:
      return "Invalid prediction data"
    }
  }
}

// MARK: - Notification Service
@MainActor
final class NotificationService: NSObject, ObservableObject {

  // MARK: - Singleton
  static let shared = NotificationService()

  // MARK: - Properties
  @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
  private let notificationCenter = UNUserNotificationCenter.current()

  // MARK: - Constants
  private struct NotificationIdentifiers {
    static let predictionReminder = "prediction_reminder"
    static let categoryIdentifier = "PREDICTION_ACTION"
    static let viewActionIdentifier = "VIEW_PREDICTION"
    static let resolveCorrectActionIdentifier = "RESOLVE_CORRECT"
    static let resolveIncorrectActionIdentifier = "RESOLVE_INCORRECT"
  }

  // MARK: - Initialization
  override init() {
    super.init()
    notificationCenter.delegate = self
    setupNotificationCategories()
    // Note: checkAuthorizationStatus() is now called only when needed
  }

  // MARK: - Permission Management
  func requestNotificationPermission() async throws {
    // Check current status first
    await checkAuthorizationStatus()

    // If already authorized, no need to request again
    if authorizationStatus == .authorized {
      return
    }

    let options: UNAuthorizationOptions = [.alert, .badge, .sound]

    do {
      let granted = try await notificationCenter.requestAuthorization(
        options: options
      )
      await MainActor.run {
        authorizationStatus = granted ? .authorized : .denied
      }

      if !granted {
        throw NotificationServiceError.permissionDenied
      }
    } catch {
      throw NotificationServiceError.schedulingFailed(error)
    }
  }

  func checkAuthorizationStatus() async {
    let settings = await notificationCenter.notificationSettings()
    await MainActor.run {
      authorizationStatus = settings.authorizationStatus
    }
  }

  // MARK: - Notification Setup
  private func setupNotificationCategories() {
    let viewAction = UNNotificationAction(
      identifier: NotificationIdentifiers.viewActionIdentifier,
      title: "View Details",
      options: [.foreground]
    )

    let resolveCorrectAction = UNNotificationAction(
      identifier: NotificationIdentifiers.resolveCorrectActionIdentifier,
      title: "Mark Correct",
      options: []
    )

    let resolveIncorrectAction = UNNotificationAction(
      identifier: NotificationIdentifiers.resolveIncorrectActionIdentifier,
      title: "Mark Wrong",
      options: []
    )

    let category = UNNotificationCategory(
      identifier: NotificationIdentifiers.categoryIdentifier,
      actions: [viewAction, resolveCorrectAction, resolveIncorrectAction],
      intentIdentifiers: [],
      options: []
    )

    notificationCenter.setNotificationCategories([category])
  }

  // MARK: - Scheduling Notifications
  func scheduleReminderForPrediction(_ prediction: Prediction) async throws {
    // Check authorization status first
    await checkAuthorizationStatus()

    guard authorizationStatus == .authorized else {
      throw NotificationServiceError.permissionDenied
    }

    guard !prediction.isResolved else { return }

    let dueDateNotification = try createDueDateNotification(for: prediction)
    try await notificationCenter.add(dueDateNotification)

    if prediction.dueDate.timeIntervalSinceNow > 86400 {
      let reminderNotification = try createReminderNotification(for: prediction)
      try await notificationCenter.add(reminderNotification)
    }
  }

  func cancelNotificationsForPrediction(_ prediction: Prediction) {
    let identifiers = [
      "\(NotificationIdentifiers.predictionReminder)_\(prediction.id.uuidString)",
      "\(NotificationIdentifiers.predictionReminder)_reminder_\(prediction.id.uuidString)",
    ]
    notificationCenter.removePendingNotificationRequests(
      withIdentifiers: identifiers
    )
  }

  func cancelAllNotifications() {
    notificationCenter.removeAllPendingNotificationRequests()
  }

  // MARK: - Notification Creation
  private func createDueDateNotification(for prediction: Prediction) throws
    -> UNNotificationRequest
  {
    let content = UNMutableNotificationContent()
    content.title = "Prediction Due Today"
    content.body = "Time to resolve: \(prediction.title)"
    content.sound = .default
    content.categoryIdentifier = NotificationIdentifiers.categoryIdentifier
    content.userInfo = [
      "predictionId": prediction.id.uuidString,
      "type": "dueDate",
    ]

    let triggerDate = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: prediction.dueDate
    )
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: triggerDate,
      repeats: false
    )

    let identifier =
      "\(NotificationIdentifiers.predictionReminder)_\(prediction.id.uuidString)"
    return UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
  }

  private func createReminderNotification(for prediction: Prediction) throws
    -> UNNotificationRequest
  {
    let content = UNMutableNotificationContent()
    content.title = "Prediction Due Tomorrow"
    content.body = "Don't forget: \(prediction.title)"
    content.sound = .default
    content.categoryIdentifier = NotificationIdentifiers.categoryIdentifier
    content.userInfo = [
      "predictionId": prediction.id.uuidString,
      "type": "reminder",
    ]

    let reminderDate =
      Calendar.current.date(byAdding: .day, value: -1, to: prediction.dueDate)
      ?? prediction.dueDate
    let triggerDate = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: reminderDate
    )
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: triggerDate,
      repeats: false
    )

    let identifier =
      "\(NotificationIdentifiers.predictionReminder)_reminder_\(prediction.id.uuidString)"
    return UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
  }

}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (
      UNNotificationPresentationOptions
    ) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard
      let predictionIdString = response.notification.request.content.userInfo[
        "predictionId"
      ] as? String,
      let predictionId = UUID(uuidString: predictionIdString)
    else {
      completionHandler()
      return
    }

    Task {
      await handleNotificationResponse(response, predictionId: predictionId)
      completionHandler()
    }
  }

  @MainActor
  private func handleNotificationResponse(
    _ response: UNNotificationResponse,
    predictionId: UUID
  ) async {
    switch response.actionIdentifier {
    case NotificationIdentifiers.viewActionIdentifier:
      NotificationCenter.default.post(
        name: .showPredictionDetail,
        object: nil,
        userInfo: ["predictionId": predictionId]
      )

    case NotificationIdentifiers.resolveCorrectActionIdentifier:
      await resolvePrediction(predictionId: predictionId, outcome: "Correct")

    case NotificationIdentifiers.resolveIncorrectActionIdentifier:
      await resolvePrediction(predictionId: predictionId, outcome: "Incorrect")

    case UNNotificationDefaultActionIdentifier:
      NotificationCenter.default.post(
        name: .showPredictionDetail,
        object: nil,
        userInfo: ["predictionId": predictionId]
      )

    default:
      break
    }
  }

  private func resolvePrediction(predictionId: UUID, outcome: String) async {
    NotificationCenter.default.post(
      name: .resolvePredictionFromNotification,
      object: nil,
      userInfo: ["predictionId": predictionId, "outcome": outcome]
    )
  }
}

// MARK: - Notification Names
extension Notification.Name {
  static let showPredictionDetail = Notification.Name("showPredictionDetail")
  static let resolvePredictionFromNotification = Notification.Name(
    "resolvePredictionFromNotification"
  )
}
