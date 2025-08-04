//
//  DIContainerEnvironment.swift
//  Delphi
//
//  Environment extension for dependency injection container
//

import SwiftUI

// MARK: - Environment Key
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer? = nil
}

// MARK: - Environment Values Extension
extension EnvironmentValues {
    var diContainer: DIContainer? {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// MARK: - View Extensions for DI
extension View {
    func environmentDIContainer(_ container: DIContainer) -> some View {
        environment(\.diContainer, container)
    }
}
