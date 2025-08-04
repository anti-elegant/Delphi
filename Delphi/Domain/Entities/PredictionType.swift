import Foundation

// MARK: - Prediction Type
enum PredictionType: String, CaseIterable, Codable, Sendable {
  // MARK: - Legacy Types (maintained for backward compatibility)
  case personal = "personal"
  case professional = "professional"
  
  // MARK: - Expanded Types
  case health = "health"
  case career = "career"
  case relationships = "relationships"
  case finance = "finance"
  case weather = "weather"
  case sports = "sports"
  case technology = "technology"
  case politics = "politics"
  case entertainment = "entertainment"
  case education = "education"
  case travel = "travel"
  case business = "business"
  case social = "social"
  case family = "family"
  case hobbies = "hobbies"
  case lifestyle = "lifestyle"
  case science = "science"
  case economics = "economics"
  case other = "other"
  
  var displayName: String {
    switch self {
    case .personal:
      return "Personal"
    case .professional:
      return "Professional"
    case .health:
      return "Health & Wellness"
    case .career:
      return "Career"
    case .relationships:
      return "Relationships"
    case .finance:
      return "Finance"
    case .weather:
      return "Weather"
    case .sports:
      return "Sports"
    case .technology:
      return "Technology"
    case .politics:
      return "Politics"
    case .entertainment:
      return "Entertainment"
    case .education:
      return "Education"
    case .travel:
      return "Travel"
    case .business:
      return "Business"
    case .social:
      return "Social"
    case .family:
      return "Family"
    case .hobbies:
      return "Hobbies"
    case .lifestyle:
      return "Lifestyle"
    case .science:
      return "Science"
    case .economics:
      return "Economics"
    case .other:
      return "Other"
    }
  }
  
  var description: String {
    switch self {
    case .personal:
      return "Personal predictions about your life"
    case .professional:
      return "Work-related predictions"
    case .health:
      return "Health, fitness, and wellness predictions"
    case .career:
      return "Career advancement and professional development"
    case .relationships:
      return "Personal and romantic relationships"
    case .finance:
      return "Financial markets, investments, and personal finance"
    case .weather:
      return "Weather forecasts and climate predictions"
    case .sports:
      return "Sports outcomes and athletic performance"
    case .technology:
      return "Technology trends and innovations"
    case .politics:
      return "Political events and election outcomes"
    case .entertainment:
      return "Movies, TV, music, and entertainment industry"
    case .education:
      return "Academic achievements and learning outcomes"
    case .travel:
      return "Travel plans and destination experiences"
    case .business:
      return "Business performance and market trends"
    case .social:
      return "Social events and community activities"
    case .family:
      return "Family events and milestones"
    case .hobbies:
      return "Personal interests and hobby activities"
    case .lifestyle:
      return "Lifestyle changes and personal habits"
    case .science:
      return "Scientific discoveries and research outcomes"
    case .economics:
      return "Economic trends and market predictions"
    case .other:
      return "Predictions that don't fit other categories"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .personal:
      return "person.circle"
    case .professional:
      return "briefcase"
    case .health:
      return "heart"
    case .career:
      return "star"
    case .relationships:
      return "heart.circle"
    case .finance:
      return "dollarsign.circle"
    case .weather:
      return "cloud.sun"
    case .sports:
      return "sportscourt"
    case .technology:
      return "laptopcomputer"
    case .politics:
      return "building.columns"
    case .entertainment:
      return "tv"
    case .education:
      return "graduationcap"
    case .travel:
      return "airplane"
    case .business:
      return "building.2"
    case .social:
      return "person.2"
    case .family:
      return "house"
    case .hobbies:
      return "gamecontroller"
    case .lifestyle:
      return "leaf"
    case .science:
      return "flask"
    case .economics:
      return "chart.line.uptrend.xyaxis"
    case .other:
      return "ellipsis.circle"
    }
  }
  
  var color: String {
    switch self {
    case .personal:
      return "blue"
    case .professional:
      return "indigo"
    case .health:
      return "red"
    case .career:
      return "purple"
    case .relationships:
      return "pink"
    case .finance:
      return "green"
    case .weather:
      return "cyan"
    case .sports:
      return "orange"
    case .technology:
      return "gray"
    case .politics:
      return "brown"
    case .entertainment:
      return "yellow"
    case .education:
      return "mint"
    case .travel:
      return "teal"
    case .business:
      return "indigo"
    case .social:
      return "blue"
    case .family:
      return "orange"
    case .hobbies:
      return "purple"
    case .lifestyle:
      return "green"
    case .science:
      return "cyan"
    case .economics:
      return "green"
    case .other:
      return "gray"
    }
  }
  
  /// Categories for grouping prediction types
  var category: PredictionCategory {
    switch self {
    case .personal, .relationships, .family, .lifestyle:
      return .personal
    case .professional, .career, .business:
      return .work
    case .health:
      return .health
    case .finance, .economics:
      return .financial
    case .sports, .entertainment, .hobbies:
      return .entertainment
    case .technology, .science, .education:
      return .knowledge
    case .weather, .politics, .social, .travel:
      return .external
    case .other:
      return .other
    }
  }
  
  /// Legacy compatibility check
  var isLegacyType: Bool {
    self == .personal || self == .professional
  }
}

// MARK: - Prediction Category for Grouping
enum PredictionCategory: String, CaseIterable, Codable, Sendable {
  case personal = "personal"
  case work = "work"
  case health = "health"
  case financial = "financial"
  case entertainment = "entertainment"
  case knowledge = "knowledge"
  case external = "external"
  case other = "other"
  
  var displayName: String {
    switch self {
    case .personal: return "Personal & Family"
    case .work: return "Work & Career"
    case .health: return "Health & Wellness"
    case .financial: return "Finance & Economics"
    case .entertainment: return "Sports & Entertainment"
    case .knowledge: return "Knowledge & Learning"
    case .external: return "External Events"
    case .other: return "Other"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .personal: return "person.circle"
    case .work: return "briefcase"
    case .health: return "heart"
    case .financial: return "dollarsign.circle"
    case .entertainment: return "tv"
    case .knowledge: return "brain"
    case .external: return "globe"
    case .other: return "ellipsis.circle"
    }
  }
}

// MARK: - Extensions
extension PredictionType: Identifiable {
  var id: String { rawValue }
}


extension PredictionCategory: Identifiable {
  var id: String { rawValue }
}
