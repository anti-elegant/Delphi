import Foundation
import SwiftData

// MARK: - Dependency Injection Container
final class DIContainer {
  static let shared = DIContainer()
  
  // MARK: - Model Context
  private var modelContext: ModelContext?
  
  // MARK: - Repositories
  private lazy var predictionRepository: PredictionRepositoryProtocol = {
    guard let context = modelContext else {
      fatalError("ModelContext must be set before accessing prediction repository")
    }
    return LocalPredictionRepository(modelContext: context)
  }()
  
  private lazy var settingsRepository: SettingsRepositoryProtocol = {
    UserDefaultsSettingsRepository()
  }()
  
  // MARK: - Use Cases
  private lazy var createPredictionUseCase: CreatePredictionUseCase = {
    DefaultCreatePredictionUseCase(repository: predictionRepository)
  }()
  
  private lazy var getPredictionsUseCase: GetPredictionsUseCase = {
    DefaultGetPredictionsUseCase(repository: predictionRepository)
  }()
  
  private lazy var resolvePredictionUseCase: ResolvePredictionUseCase = {
    DefaultResolvePredictionUseCase(repository: predictionRepository)
  }()
  
  private lazy var deletePredictionUseCase: DeletePredictionUseCase = {
    DefaultDeletePredictionUseCase(repository: predictionRepository)
  }()
  
  private lazy var calculateAccuracyUseCase: CalculateAccuracyUseCase = {
    DefaultCalculateAccuracyUseCase(repository: predictionRepository)
  }()
  
  private lazy var getAnalyticsSummaryUseCase: GetAnalyticsSummaryUseCase = {
    DefaultGetAnalyticsSummaryUseCase(
      predictionRepository: predictionRepository,
      accuracyUseCase: calculateAccuracyUseCase
    )
  }()
  
  private lazy var manageSettingsUseCase: ManageSettingsUseCase = {
    DefaultManageSettingsUseCase(repository: settingsRepository)
  }()
  
  private lazy var exportDataUseCase: ExportDataUseCase = {
    DefaultExportDataUseCase(
      predictionRepository: predictionRepository,
      settingsRepository: settingsRepository,
      accuracyUseCase: calculateAccuracyUseCase
    )
  }()
  
  private lazy var clearAllDataUseCase: ClearAllDataUseCase = {
    DefaultClearAllDataUseCase(
      predictionRepository: predictionRepository,
      settingsRepository: settingsRepository
    )
  }()
  
  // MARK: - Initialization
  private init() {}
  
  // MARK: - Configuration
  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }
  
  // MARK: - Public Interface
  func makeCreatePredictionUseCase() -> CreatePredictionUseCase {
    createPredictionUseCase
  }
  
  func makeGetPredictionsUseCase() -> GetPredictionsUseCase {
    getPredictionsUseCase
  }
  
  func makeResolvePredictionUseCase() -> ResolvePredictionUseCase {
    resolvePredictionUseCase
  }
  
  func makeDeletePredictionUseCase() -> DeletePredictionUseCase {
    deletePredictionUseCase
  }
  
  func makeCalculateAccuracyUseCase() -> CalculateAccuracyUseCase {
    calculateAccuracyUseCase
  }
  
  func makeGetAnalyticsSummaryUseCase() -> GetAnalyticsSummaryUseCase {
    getAnalyticsSummaryUseCase
  }
  
  func makeManageSettingsUseCase() -> ManageSettingsUseCase {
    manageSettingsUseCase
  }
  
  func makeExportDataUseCase() -> ExportDataUseCase {
    exportDataUseCase
  }
  
  func makeClearAllDataUseCase() -> ClearAllDataUseCase {
    clearAllDataUseCase
  }
  
  // MARK: - Repository Access (for testing and data layer)
  func makePredictionRepository() -> PredictionRepositoryProtocol {
    predictionRepository
  }
  
  func makeSettingsRepository() -> SettingsRepositoryProtocol {
    settingsRepository
  }
}

// MARK: - View Model Factory
extension DIContainer {
  @MainActor
  func makePredictionListViewModel() -> PredictionListViewModel {
    PredictionListViewModel(
      getPredictionsUseCase: makeGetPredictionsUseCase(),
      deletePredictionUseCase: makeDeletePredictionUseCase(),
      resolvePredictionUseCase: makeResolvePredictionUseCase()
    )
  }
  
  @MainActor
  func makePredictionFormViewModel() -> PredictionFormViewModel {
    PredictionFormViewModel(
      createPredictionUseCase: makeCreatePredictionUseCase()
    )
  }
  
  @MainActor
  func makeAnalyticsViewModel() -> AnalyticsViewModel {
    AnalyticsViewModel(
      getAnalyticsSummaryUseCase: makeGetAnalyticsSummaryUseCase()
    )
  }
  
  @MainActor
  func makeSettingsViewModel() -> SettingsViewModel {
    SettingsViewModel(
      manageSettingsUseCase: makeManageSettingsUseCase(),
      exportDataUseCase: makeExportDataUseCase(),
      clearAllDataUseCase: makeClearAllDataUseCase()
    )
  }
}

// MARK: - Coordinator Factory
extension DIContainer {
  @MainActor
  func makeAppCoordinator() -> AppCoordinator {
    AppCoordinator(container: self)
  }
}

// MARK: - Testing Support
#if DEBUG
extension DIContainer {
  static func makeTestContainer() -> DIContainer {
    let container = DIContainer()
    // Inject test repositories here if needed
    return container
  }
}
#endif
