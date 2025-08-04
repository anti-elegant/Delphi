//
//  BaseViewModel.swift
//  Delphi
//
//  Base class for all ViewModels providing common functionality
//

import Foundation
import Combine

@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Execute an async operation with loading state management
    func executeWithLoading<T>(_ operation: @escaping () async throws -> T) async -> T? {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            return try await operation()
        } catch {
            self.error = error
            return nil
        }
    }
    
    /// Execute an async operation with loading state management (void return)
    func executeWithLoading(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await operation()
        } catch {
            self.error = error
        }
    }
    
    /// Clear the current error
    func clearError() {
        error = nil
    }
    
    /// Check if there's an error
    var hasError: Bool {
        error != nil
    }
    
    /// Get error message
    var errorMessage: String? {
        error?.localizedDescription
    }
}
