import Foundation
import SwiftData

// MARK: - Sample Data Seeder Error Types
enum SampleDataSeederError: LocalizedError {
  case contextNotAvailable
  case seedingFailed(Error)
  case dataCheckFailed(Error)

  var errorDescription: String? {
    switch self {
    case .contextNotAvailable:
      return "Model context is not available"
    case .seedingFailed(let error):
      return "Failed to seed sample data: \(error.localizedDescription)"
    case .dataCheckFailed(let error):
      return "Failed to check existing data: \(error.localizedDescription)"
    }
  }
}

// MARK: - Sample Data Seeder
struct SampleDataSeeder {

  // MARK: - Public Interface
  static func seedSampleData(in modelContext: ModelContext) {
    Task {
      do {
        try await seedSampleDataAsync(in: modelContext)
      } catch {
        print("Sample data seeding failed: \(error.localizedDescription)")
      }
    }
  }

  @MainActor
  static func seedSampleDataAsync(in modelContext: ModelContext) async throws {
    // Check if data already exists
    do {
      let descriptor = FetchDescriptor<Prediction>()
      let existingCount = try modelContext.fetchCount(descriptor)

      if existingCount > 0 {
        print("Sample data already exists (\(existingCount) predictions found)")
        return
      }
    } catch {
      throw SampleDataSeederError.dataCheckFailed(error)
    }

    print("Seeding sample data...")

    do {
      let samplePredictions = createSamplePredictions()

      for prediction in samplePredictions {
        modelContext.insert(prediction)
      }

      try modelContext.save()
      print("Successfully seeded \(samplePredictions.count) sample predictions")

    } catch {
      throw SampleDataSeederError.seedingFailed(error)
    }
  }

  // MARK: - Private Helper Methods
  private static func createSamplePredictions() -> [Prediction] {
    let now = Date()
    let calendar = Calendar.current

    return [
      Prediction(
        eventName: "Election Results",
        eventDescription:
          "I predict that voter turnout will be higher than 2020, with over 75% participation in key swing states. This is based on increased political engagement and improved access to voting.",
        confidenceLevel: 75.0,
        estimatedValue: "",
        booleanValue: "Yes",
        pressureLevel: "High",
        currentMood: "Good",
        takesMedicine: "No",
        evidenceList: [
          "Historical voting patterns show increasing turnout trends",
          "Recent polling data indicates high voter enthusiasm",
          "Social media engagement metrics are at record levels",
          "Early voting numbers exceed previous elections",
        ],
        selectedType: .boolean,
        dueDate: calendar.date(byAdding: .day, value: 30, to: now) ?? now
      ),

      Prediction(
        eventName: "Apple WWDC 2025 AI Announcement",
        eventDescription:
          "Apple will announce significant AI integration across iOS, macOS, and introduce new developer tools for machine learning. This will include on-device AI processing and enhanced Siri capabilities.",
        confidenceLevel: 85.0,
        estimatedValue: "",
        booleanValue: "Yes",
        pressureLevel: "Medium",
        currentMood: "Excellent",
        takesMedicine: "No",
        evidenceList: [
          "Industry trends showing rapid AI adoption",
          "Apple's recent AI investments and acquisitions",
          "Developer community feedback requesting AI tools",
          "Competitive pressure from Google and Microsoft",
        ],
        selectedType: .boolean,
        dueDate: calendar.date(byAdding: .day, value: 120, to: now) ?? now
      ),

      Prediction(
        eventName: "Bitcoin Price Target",
        eventDescription:
          "Bitcoin price will reach $95,000 by the end of 2025, driven by institutional adoption and regulatory clarity.",
        confidenceLevel: 60.0,
        estimatedValue: "95000",
        booleanValue: "Yes",
        pressureLevel: "Low",
        currentMood: "Good",
        takesMedicine: "No",
        evidenceList: [
          "Comprehensive market analysis shows bullish trends",
          "Institutional adoption increasing steadily",
          "Regulatory developments favoring cryptocurrency",
          "ETF approvals driving mainstream acceptance",
        ],
        selectedType: .numeric,
        dueDate: calendar.date(byAdding: .day, value: 365, to: now) ?? now
      ),

      Prediction(
        eventName: "Climate Summit Agreement",
        eventDescription:
          "The upcoming climate summit will result in significant new international agreements on carbon reduction targets, with at least 150 countries committing to net-zero by 2050.",
        confidenceLevel: 70.0,
        estimatedValue: "",
        booleanValue: "Yes",
        pressureLevel: "High",
        currentMood: "Fair",
        takesMedicine: "No",
        evidenceList: [
          "Previous summit outcomes show progress",
          "Current political climate favors environmental action",
          "Environmental urgency increasing pressure",
          "Economic incentives aligning with climate goals",
        ],
        selectedType: .boolean,
        dueDate: calendar.date(byAdding: .day, value: -15, to: now) ?? now  // Overdue
      ),

      Prediction(
        eventName: "Mars Mission Success",
        eventDescription:
          "The next Mars mission will successfully launch and reach orbit within the planned timeframe, marking a significant milestone in space exploration.",
        confidenceLevel: 90.0,
        estimatedValue: "",
        booleanValue: "Yes",
        pressureLevel: "Medium",
        currentMood: "Excellent",
        takesMedicine: "No",
        evidenceList: [
          "Technical specifications meet all requirements",
          "Previous mission success rates are high",
          "Weather forecasts are favorable",
          "Backup systems are thoroughly tested",
        ],
        selectedType: .boolean,
        dueDate: calendar.date(byAdding: .day, value: -45, to: now) ?? now  // Overdue
      ),

      Prediction(
        eventName: "Stock Market Performance",
        eventDescription:
          "The S&P 500 will reach 5,800 points by year-end, driven by continued economic growth and technological innovation.",
        confidenceLevel: 55.0,
        estimatedValue: "5800",
        booleanValue: "Yes",
        pressureLevel: "High",
        currentMood: "Good",
        takesMedicine: "Yes",
        evidenceList: [
          "Economic indicators show steady growth",
          "Corporate earnings continue to rise",
          "Federal Reserve policy remains supportive",
          "Technology sector leading innovation",
        ],
        selectedType: .numeric,
        dueDate: calendar.date(byAdding: .day, value: 200, to: now) ?? now
      ),
    ]
  }

  // MARK: - Utility Methods
  static func clearAllData(in modelContext: ModelContext) async throws {
    do {
      let descriptor = FetchDescriptor<Prediction>()
      let predictions = try modelContext.fetch(descriptor)

      for prediction in predictions {
        modelContext.delete(prediction)
      }

      try modelContext.save()
      print(
        "Cleared all sample data (\(predictions.count) predictions removed)"
      )

    } catch {
      throw SampleDataSeederError.seedingFailed(error)
    }
  }

  static func reseedData(in modelContext: ModelContext) async throws {
    try await clearAllData(in: modelContext)
    try await seedSampleDataAsync(in: modelContext)
    print("Data reseeded successfully")
  }
}
