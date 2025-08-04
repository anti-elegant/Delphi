import Foundation

// MARK: - Prediction Context Domain Entity
struct PredictionContext {
  // MARK: - Core Context Properties
  let mood: MoodLevel?
  let pressure: PressureLevel?
  let medication: MedicationStatus?
  let sleepQuality: SleepQuality?
  let stressFactors: [StressFactor]
  let environmentalFactors: [String]
  let externalInfluences: [String]
  let notes: String?
  let tags: [String]
  
  // MARK: - Timing Context
  let timeOfDay: TimeOfDay?
  let dayOfWeek: DayOfWeek?
  
  // MARK: - Legacy Support
  let additionalEvidence: [String] // For backward compatibility
  
  // MARK: - Computed Properties
  var hasHealthContext: Bool {
    mood != nil || pressure != nil || medication != nil || sleepQuality != nil || !stressFactors.isEmpty
  }
  
  var hasEnvironmentalContext: Bool {
    !environmentalFactors.isEmpty || !externalInfluences.isEmpty
  }
  
  var hasTimingContext: Bool {
    timeOfDay != nil || dayOfWeek != nil
  }
  
  var isEmpty: Bool {
    mood == nil &&
    pressure == nil &&
    medication == nil &&
    sleepQuality == nil &&
    stressFactors.isEmpty &&
    environmentalFactors.isEmpty &&
    externalInfluences.isEmpty &&
    (notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
    tags.isEmpty &&
    timeOfDay == nil &&
    dayOfWeek == nil &&
    additionalEvidence.isEmpty
  }
  
  var allEvidence: [String] {
    var evidence: [String] = []
    
    if let mood = mood {
      evidence.append("Mood: \(mood.displayName)")
    }
    
    if let pressure = pressure {
      evidence.append("Pressure: \(pressure.displayName)")
    }
    
    if let medication = medication {
      evidence.append("Medication: \(medication.displayName)")
    }
    
    if let sleepQuality = sleepQuality {
      evidence.append("Sleep: \(sleepQuality.displayName)")
    }
    
    if !stressFactors.isEmpty {
      evidence.append("Stress: \(stressFactors.map { $0.displayName }.joined(separator: ", "))")
    }
    
    if !environmentalFactors.isEmpty {
      evidence.append("Environment: \(environmentalFactors.joined(separator: ", "))")
    }
    
    if !externalInfluences.isEmpty {
      evidence.append("Influences: \(externalInfluences.joined(separator: ", "))")
    }
    
    if let timeOfDay = timeOfDay {
      evidence.append("Time: \(timeOfDay.displayName)")
    }
    
    if let dayOfWeek = dayOfWeek {
      evidence.append("Day: \(dayOfWeek.displayName)")
    }
    
    if !tags.isEmpty {
      evidence.append("Tags: \(tags.joined(separator: ", "))")
    }
    
    if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      evidence.append("Notes: \(notes)")
    }
    
    evidence.append(contentsOf: additionalEvidence)
    
    return evidence
  }
}

// MARK: - Mood Level
enum MoodLevel: String, CaseIterable, Codable, Sendable {
  case veryLow = "very_low"
  case low = "low"
  case neutral = "neutral"
  case good = "good"
  case excellent = "excellent"
  
  var displayName: String {
    switch self {
    case .veryLow: return "Very Low"
    case .low: return "Low"
    case .neutral: return "Neutral"
    case .good: return "Good"
    case .excellent: return "Excellent"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .veryLow: return "face.dashed"
    case .low: return "face.dashed.fill"
    case .neutral: return "face.smiling"
    case .good: return "face.smiling.fill"
    case .excellent: return "face.smiling.inverse"
    }
  }
}

// MARK: - Pressure Level
enum PressureLevel: String, CaseIterable, Codable, Sendable {
  case none = "none"
  case low = "low"
  case moderate = "moderate"
  case high = "high"
  case extreme = "extreme"
  
  var displayName: String {
    switch self {
    case .none: return "No Pressure"
    case .low: return "Low Pressure"
    case .moderate: return "Moderate Pressure"
    case .high: return "High Pressure"
    case .extreme: return "Extreme Pressure"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .none: return "gauge.low"
    case .low: return "gauge.low"
    case .moderate: return "gauge.medium"
    case .high: return "gauge.high"
    case .extreme: return "exclamationmark.gauge"
    }
  }
}

// MARK: - Medication Status
enum MedicationStatus: String, CaseIterable, Codable, Sendable {
  case none = "none"
  case regular = "regular"
  case missed = "missed"
  case changed = "changed"
  case newMedication = "new_medication"
  
  var displayName: String {
    switch self {
    case .none: return "No Medication"
    case .regular: return "Regular Medication"
    case .missed: return "Missed Medication"
    case .changed: return "Changed Medication"
    case .newMedication: return "New Medication"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .none: return "pills"
    case .regular: return "pills.fill"
    case .missed: return "pills.circle"
    case .changed: return "pills.circle.fill"
    case .newMedication: return "plus.circle.fill"
    }
  }
}

// MARK: - Sleep Quality
enum SleepQuality: String, CaseIterable, Codable, Sendable {
  case terrible = "terrible"
  case poor = "poor"
  case fair = "fair"
  case good = "good"
  case excellent = "excellent"
  
  var displayName: String {
    switch self {
    case .terrible: return "Terrible"
    case .poor: return "Poor"
    case .fair: return "Fair"
    case .good: return "Good"
    case .excellent: return "Excellent"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .terrible: return "bed.double"
    case .poor: return "bed.double.fill"
    case .fair: return "moon"
    case .good: return "moon.fill"
    case .excellent: return "moon.stars.fill"
    }
  }
}

// MARK: - Stress Factor
enum StressFactor: String, CaseIterable, Codable, Sendable {
  case work = "work"
  case family = "family"
  case health = "health"
  case financial = "financial"
  case relationship = "relationship"
  case social = "social"
  case academic = "academic"
  case travel = "travel"
  case deadlines = "deadlines"
  case uncertainty = "uncertainty"
  case other = "other"
  
  var displayName: String {
    switch self {
    case .work: return "Work"
    case .family: return "Family"
    case .health: return "Health"
    case .financial: return "Financial"
    case .relationship: return "Relationship"
    case .social: return "Social"
    case .academic: return "Academic"
    case .travel: return "Travel"
    case .deadlines: return "Deadlines"
    case .uncertainty: return "Uncertainty"
    case .other: return "Other"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .work: return "briefcase"
    case .family: return "house"
    case .health: return "heart"
    case .financial: return "dollarsign.circle"
    case .relationship: return "heart.circle"
    case .social: return "person.2"
    case .academic: return "graduationcap"
    case .travel: return "airplane"
    case .deadlines: return "clock.badge.exclamationmark"
    case .uncertainty: return "questionmark.circle"
    case .other: return "ellipsis.circle"
    }
  }
}

// MARK: - Time of Day
enum TimeOfDay: String, CaseIterable, Codable, Sendable {
  case earlyMorning = "early_morning"
  case morning = "morning"
  case lateMoving = "late_morning"
  case afternoon = "afternoon"
  case evening = "evening"
  case night = "night"
  case lateNight = "late_night"
  
  var displayName: String {
    switch self {
    case .earlyMorning: return "Early Morning (5-7 AM)"
    case .morning: return "Morning (7-10 AM)"
    case .lateMoving: return "Late Morning (10 AM-12 PM)"
    case .afternoon: return "Afternoon (12-5 PM)"
    case .evening: return "Evening (5-8 PM)"
    case .night: return "Night (8-11 PM)"
    case .lateNight: return "Late Night (11 PM-5 AM)"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .earlyMorning: return "sunrise"
    case .morning: return "sun.max"
    case .lateMoving: return "sun.max.fill"
    case .afternoon: return "sun.max"
    case .evening: return "sunset"
    case .night: return "moon"
    case .lateNight: return "moon.fill"
    }
  }
}

// MARK: - Day of Week
enum DayOfWeek: String, CaseIterable, Codable, Sendable {
  case monday = "monday"
  case tuesday = "tuesday"
  case wednesday = "wednesday"
  case thursday = "thursday"
  case friday = "friday"
  case saturday = "saturday"
  case sunday = "sunday"
  
  var displayName: String {
    rawValue.capitalized
  }
  
  var isWeekend: Bool {
    self == .saturday || self == .sunday
  }
  
  var isWeekday: Bool {
    !isWeekend
  }
}

// MARK: - Initializers
extension PredictionContext {
  static let empty = PredictionContext(
    mood: nil,
    pressure: nil,
    medication: nil,
    sleepQuality: nil,
    stressFactors: [],
    environmentalFactors: [],
    externalInfluences: [],
    notes: nil,
    tags: [],
    timeOfDay: nil,
    dayOfWeek: nil,
    additionalEvidence: []
  )
  
  /// Create context from legacy evidence array for backward compatibility
  static func fromLegacyEvidence(_ evidence: [String]) -> PredictionContext {
    PredictionContext(
      mood: nil,
      pressure: nil,
      medication: nil,
      sleepQuality: nil,
      stressFactors: [],
      environmentalFactors: [],
      externalInfluences: [],
      notes: nil,
      tags: [],
      timeOfDay: nil,
      dayOfWeek: nil,
      additionalEvidence: evidence
    )
  }
}

// MARK: - Protocol Conformances
extension PredictionContext: Equatable {}

extension PredictionContext: Codable {}

extension PredictionContext: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(mood)
    hasher.combine(pressure)
    hasher.combine(medication)
    hasher.combine(sleepQuality)
    hasher.combine(stressFactors)
    hasher.combine(environmentalFactors)
    hasher.combine(externalInfluences)
    hasher.combine(notes)
    hasher.combine(tags)
    hasher.combine(timeOfDay)
    hasher.combine(dayOfWeek)
    hasher.combine(additionalEvidence)
  }
}

// MARK: - Update Methods
extension PredictionContext {
  func withMood(_ mood: MoodLevel?) -> PredictionContext {
    PredictionContext(
      mood: mood,
      pressure: self.pressure,
      medication: self.medication,
      sleepQuality: self.sleepQuality,
      stressFactors: self.stressFactors,
      environmentalFactors: self.environmentalFactors,
      externalInfluences: self.externalInfluences,
      notes: self.notes,
      tags: self.tags,
      timeOfDay: self.timeOfDay,
      dayOfWeek: self.dayOfWeek,
      additionalEvidence: self.additionalEvidence
    )
  }
  
  func withPressure(_ pressure: PressureLevel?) -> PredictionContext {
    PredictionContext(
      mood: self.mood,
      pressure: pressure,
      medication: self.medication,
      sleepQuality: self.sleepQuality,
      stressFactors: self.stressFactors,
      environmentalFactors: self.environmentalFactors,
      externalInfluences: self.externalInfluences,
      notes: self.notes,
      tags: self.tags,
      timeOfDay: self.timeOfDay,
      dayOfWeek: self.dayOfWeek,
      additionalEvidence: self.additionalEvidence
    )
  }
  
  func withStressFactors(_ stressFactors: [StressFactor]) -> PredictionContext {
    PredictionContext(
      mood: self.mood,
      pressure: self.pressure,
      medication: self.medication,
      sleepQuality: self.sleepQuality,
      stressFactors: stressFactors,
      environmentalFactors: self.environmentalFactors,
      externalInfluences: self.externalInfluences,
      notes: self.notes,
      tags: self.tags,
      timeOfDay: self.timeOfDay,
      dayOfWeek: self.dayOfWeek,
      additionalEvidence: self.additionalEvidence
    )
  }
  
  func withNotes(_ notes: String?) -> PredictionContext {
    PredictionContext(
      mood: self.mood,
      pressure: self.pressure,
      medication: self.medication,
      sleepQuality: self.sleepQuality,
      stressFactors: self.stressFactors,
      environmentalFactors: self.environmentalFactors,
      externalInfluences: self.externalInfluences,
      notes: notes,
      tags: self.tags,
      timeOfDay: self.timeOfDay,
      dayOfWeek: self.dayOfWeek,
      additionalEvidence: self.additionalEvidence
    )
  }
  
  func withTags(_ tags: [String]) -> PredictionContext {
    PredictionContext(
      mood: self.mood,
      pressure: self.pressure,
      medication: self.medication,
      sleepQuality: self.sleepQuality,
      stressFactors: self.stressFactors,
      environmentalFactors: self.environmentalFactors,
      externalInfluences: self.externalInfluences,
      notes: self.notes,
      tags: tags,
      timeOfDay: self.timeOfDay,
      dayOfWeek: self.dayOfWeek,
      additionalEvidence: self.additionalEvidence
    )
  }
}

// MARK: - Validation
extension PredictionContext {
  enum ValidationError: LocalizedError {
    case tooManyStressFactors
    case invalidNotes
    case tooManyTags
    
    var errorDescription: String? {
      switch self {
      case .tooManyStressFactors:
        return "Cannot have more than 10 stress factors"
      case .invalidNotes:
        return "Notes cannot exceed 500 characters"
      case .tooManyTags:
        return "Cannot have more than 20 tags"
      }
    }
  }
  
  func validate() throws {
    guard stressFactors.count <= 10 else {
      throw ValidationError.tooManyStressFactors
    }
    
    if let notes = notes, notes.count > 500 {
      throw ValidationError.invalidNotes
    }
    
    guard tags.count <= 20 else {
      throw ValidationError.tooManyTags
    }
  }
}

// MARK: - Extensions for Identifiable
extension MoodLevel: Identifiable { var id: String { rawValue } }
extension PressureLevel: Identifiable { var id: String { rawValue } }
extension MedicationStatus: Identifiable { var id: String { rawValue } }
extension SleepQuality: Identifiable { var id: String { rawValue } }
extension StressFactor: Identifiable { var id: String { rawValue } }
extension TimeOfDay: Identifiable { var id: String { rawValue } }
extension DayOfWeek: Identifiable { var id: String { rawValue } }
