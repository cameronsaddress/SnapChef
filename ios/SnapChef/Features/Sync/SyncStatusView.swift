//
//  SyncStatusView.swift
//  SnapChef
//
//  Displays sync status indicators in the UI
//

import SwiftUI

struct SyncStatusView: View {
    @StateObject private var localStore = LocalRecipeStore.shared
    @StateObject private var syncManager = SyncQueueManager.shared
    @State private var showDetails = false
    
    private var syncStats: LocalStorageStats {
        localStore.getStorageStats()
    }
    
    private var syncStatusColor: Color {
        if syncManager.isProcessing {
            return .yellow
        } else if syncStats.conflictedRecipes > 0 {
            return .red
        } else if syncStats.pendingRecipes > 0 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var syncStatusText: String {
        if syncManager.isProcessing {
            return "Syncing..."
        } else if syncStats.conflictedRecipes > 0 {
            return "\(syncStats.conflictedRecipes) conflicts"
        } else if syncStats.pendingRecipes > 0 {
            return "\(syncStats.pendingRecipes) pending"
        } else if let lastSync = syncStats.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "All synced"
        }
    }
    
    var body: some View {
        Button(action: { showDetails.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(syncStatusColor.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(syncManager.isProcessing ? 2 : 1)
                            .animation(
                                syncManager.isProcessing ?
                                    .easeInOut(duration: 1).repeatForever(autoreverses: true) :
                                    .default,
                                value: syncManager.isProcessing
                            )
                    )
                
                Text(syncStatusText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
            SyncDetailsView(stats: syncStats)
        }
    }
}

struct SyncDetailsView: View {
    let stats: LocalStorageStats
    @Environment(\.dismiss) var dismiss
    @StateObject private var syncManager = SyncQueueManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Sync Status")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let lastSync = stats.lastSyncDate {
                        Text("Last synced \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Stats
                List {
                    Section("Recipe Status") {
                        StatRow(
                            icon: "checkmark.circle.fill",
                            title: "Synced",
                            value: "\(stats.syncedRecipes)",
                            color: .green
                        )
                        
                        StatRow(
                            icon: "clock.fill",
                            title: "Pending Sync",
                            value: "\(stats.pendingRecipes)",
                            color: .orange
                        )
                        
                        StatRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Conflicts",
                            value: "\(stats.conflictedRecipes)",
                            color: .red
                        )
                        
                        StatRow(
                            icon: "person.crop.circle.badge.questionmark",
                            title: "Anonymous",
                            value: "\(stats.anonymousRecipes)",
                            color: .gray
                        )
                    }
                    
                    Section("Storage") {
                        StatRow(
                            icon: "internaldrive.fill",
                            title: "Local Recipes",
                            value: "\(stats.localRecipes)",
                            color: .blue
                        )
                        
                        StatRow(
                            icon: "icloud.fill",
                            title: "Total Recipes",
                            value: "\(stats.totalRecipes)",
                            color: .purple
                        )
                        
                        HStack {
                            Label("Sync Coverage", systemImage: "chart.pie.fill")
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(Int(stats.syncPercentage))%")
                                .foregroundColor(.white.opacity(0.7))
                                .fontWeight(.medium)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    
                    if syncManager.syncErrors.count > 0 {
                        Section("Recent Errors") {
                            ForEach(syncManager.syncErrors.prefix(5)) { error in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(error.error.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    
                                    Text(error.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .listRowBackground(Color.red.opacity(0.1))
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.black)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if stats.needsSync {
                        Button(action: {
                            Task {
                                await syncManager.startSync()
                            }
                        }) {
                            HStack {
                                if syncManager.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                
                                Text(syncManager.isProcessing ? "Syncing..." : "Sync Now")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(syncManager.isProcessing)
                    }
                }
                .padding()
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(color)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white.opacity(0.7))
                .fontWeight(.medium)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack {
            SyncStatusView()
                .padding()
            
            Spacer()
        }
    }
}