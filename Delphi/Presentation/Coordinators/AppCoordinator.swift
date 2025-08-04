//
//  AppCoordinator.swift
//  Delphi
//
//  Main coordinator for handling app navigation and view lifecycle
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: Int = 0
    @Published var isShowingPredictionForm = false
    @Published var isShowingSettings = false
    @Published var analyticsEnabled: Bool = true
    
    // MARK: - Dependencies
    private let container: DIContainer
    private let settingsViewModel: SettingsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(container: DIContainer) {
        self.container = container
        self.settingsViewModel = container.makeSettingsViewModel()
        
        // Load analytics setting and observe changes
        self.analyticsEnabled = settingsViewModel.analyticsEnabled
        
        // Observe settings changes
        settingsViewModel.$analyticsEnabled
            .sink { [weak self] enabled in
                self?.analyticsEnabled = enabled
                // If analytics is disabled and user is on analytics tab, switch to predictions
                if !enabled && self?.selectedTab == 1 {
                    self?.selectedTab = 0
                }
                // If analytics is disabled, adjust settings tab index
                if !enabled && self?.selectedTab == 2 {
                    self?.selectedTab = 1
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Tab Management
    
    func selectTab(_ index: Int) {
        selectedTab = index
    }
    
    func selectPredictionsTab() {
        selectedTab = 0
    }
    
    func selectAnalyticsTab() {
        if analyticsEnabled {
            selectedTab = 1
        }
    }
    
    func selectSettingsTab() {
        selectedTab = analyticsEnabled ? 2 : 1
    }
    
    // MARK: - Navigation
    
    func showPredictionForm() {
        isShowingPredictionForm = true
    }
    
    func hidePredictionForm() {
        isShowingPredictionForm = false
    }
    
    func showSettings() {
        isShowingSettings = true
    }
    
    func hideSettings() {
        isShowingSettings = false
    }
    
    // MARK: - View Factory Methods
    
    func makePredictionListView() -> some View {
        let viewModel = container.makePredictionListViewModel()
        return PredictionListView(
            viewModel: viewModel,
            coordinator: self
        )
    }
    
    func makePredictionFormView() -> some View {
        let viewModel = container.makePredictionFormViewModel()
        return PredictionFormView(
            viewModel: viewModel,
            coordinator: self
        )
    }
    
    func makeAnalyticsView() -> some View {
        let viewModel = container.makeAnalyticsViewModel()
        return AnalyticsView(
            viewModel: viewModel,
            coordinator: self
        )
    }
    
    func makeSettingsView() -> some View {
        return SettingsView(viewModel: settingsViewModel)
    }
    
    // MARK: - Tab View Factory
    
    func makeTabView() -> some View {
        TabView(selection: Binding(
            get: { [self] in selectedTab },
            set: { [self] in selectedTab = $0 }
        )) {
            makePredictionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Predictions")
                }
                .tag(0)
            
            if analyticsEnabled {
                makeAnalyticsView()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Analytics")
                    }
                    .tag(1)
            }
            
            makeSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(analyticsEnabled ? 2 : 1)
        }
        .sheet(isPresented: Binding(
            get: { [self] in isShowingPredictionForm },
            set: { [self] in isShowingPredictionForm = $0 }
        )) {
            self.makePredictionFormView()
        }
        .sheet(isPresented: Binding(
            get: { [self] in isShowingSettings },
            set: { [self] in isShowingSettings = $0 }
        )) {
            self.makeSettingsView()
        }
    }
}

// MARK: - Coordinator Protocol
@MainActor
protocol Coordinator: ObservableObject {
    func showPredictionForm()
    func hidePredictionForm()
    func showSettings()
    func hideSettings()
}

extension AppCoordinator: Coordinator {}
