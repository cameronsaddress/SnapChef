import SwiftUI

struct PerformanceSettingsView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "battery.25")
                                .foregroundColor(deviceManager.isLowPowerModeEnabled ? .orange : .secondary)
                            Text("Low Power Mode")
                                .fontWeight(.medium)
                            Spacer()
                            Text(deviceManager.isLowPowerModeEnabled ? "Active" : "Inactive")
                                .foregroundColor(deviceManager.isLowPowerModeEnabled ? .orange : .secondary)
                                .font(.caption)
                        }
                        
                        Text("When Low Power Mode is enabled, animations and effects are automatically reduced to save battery.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Power Management")
                } footer: {
                    Text("Low Power Mode is controlled by your device settings and will override individual animation preferences below.")
                }
                
                Section {
                    SettingsToggle(
                        icon: "play.circle",
                        title: "Animations",
                        description: "Enable smooth transitions and UI animations",
                        isOn: $deviceManager.animationsEnabled,
                        action: { deviceManager.setAnimationsEnabled($0) }
                    )
                    
                    SettingsToggle(
                        icon: "sparkles",
                        title: "Particle Effects",
                        description: "Show falling food particles and visual effects",
                        isOn: $deviceManager.particleEffectsEnabled,
                        action: { deviceManager.setParticleEffectsEnabled($0) }
                    )
                    
                    SettingsToggle(
                        icon: "arrow.triangle.2.circlepath.circle",
                        title: "Continuous Animations",
                        description: "Allow animations that repeat continuously",
                        isOn: $deviceManager.continuousAnimationsEnabled,
                        action: { deviceManager.setContinuousAnimationsEnabled($0) }
                    )
                    
                    SettingsToggle(
                        icon: "wand.and.stars",
                        title: "Heavy Effects",
                        description: "Enable advanced visual effects and overlays",
                        isOn: $deviceManager.heavyEffectsEnabled,
                        action: { deviceManager.setHeavyEffectsEnabled($0) }
                    )
                } header: {
                    Text("Visual Effects")
                } footer: {
                    Text("Disabling effects can improve performance and battery life on older devices.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.blue)
                            Text("Performance Impact")
                                .fontWeight(.medium)
                        }
                        
                        PerformanceIndicator(
                            title: "Current Settings",
                            level: currentPerformanceLevel,
                            color: currentPerformanceColor
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommendations:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(performanceRecommendations, id: \.self) { recommendation in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(recommendation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Performance")
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var currentPerformanceLevel: String {
        let enabledCount = [
            deviceManager.animationsEnabled,
            deviceManager.particleEffectsEnabled,
            deviceManager.continuousAnimationsEnabled,
            deviceManager.heavyEffectsEnabled
        ].filter { $0 }.count
        
        if deviceManager.isLowPowerModeEnabled {
            return "Battery Optimized"
        }
        
        switch enabledCount {
        case 0...1:
            return "Performance Optimized"
        case 2:
            return "Balanced"
        case 3:
            return "Enhanced"
        case 4:
            return "Full Effects"
        default:
            return "Unknown"
        }
    }
    
    private var currentPerformanceColor: Color {
        if deviceManager.isLowPowerModeEnabled {
            return .orange
        }
        
        let enabledCount = [
            deviceManager.animationsEnabled,
            deviceManager.particleEffectsEnabled,
            deviceManager.continuousAnimationsEnabled,
            deviceManager.heavyEffectsEnabled
        ].filter { $0 }.count
        
        switch enabledCount {
        case 0...1:
            return .green
        case 2:
            return .blue
        case 3:
            return .orange
        case 4:
            return .red
        default:
            return .gray
        }
    }
    
    private var performanceRecommendations: [String] {
        var recommendations: [String] = []
        
        if deviceManager.isLowPowerModeEnabled {
            recommendations.append("Effects automatically reduced for battery saving")
            return recommendations
        }
        
        let enabledCount = [
            deviceManager.animationsEnabled,
            deviceManager.particleEffectsEnabled,
            deviceManager.continuousAnimationsEnabled,
            deviceManager.heavyEffectsEnabled
        ].filter { $0 }.count
        
        switch enabledCount {
        case 0...1:
            recommendations.append("Optimal for battery life and older devices")
            recommendations.append("Consider enabling basic animations for better UX")
        case 2:
            recommendations.append("Good balance of performance and visual appeal")
            recommendations.append("Suitable for most devices")
        case 3:
            recommendations.append("Rich visual experience with good performance")
            recommendations.append("May impact battery on intensive use")
        case 4:
            recommendations.append("Maximum visual quality and effects")
            recommendations.append("Best suited for newer devices with good battery")
            recommendations.append("Consider reducing on older devices")
        default:
            break
        }
        
        return recommendations
    }
}

struct SettingsToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let action: (Bool) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) { newValue in
                    action(newValue)
                }
        }
        .padding(.vertical, 2)
    }
}

struct PerformanceIndicator: View {
    let title: String
    let level: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(level)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < performanceLevelBars ? color : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 16)
                }
            }
        }
    }
    
    private var performanceLevelBars: Int {
        switch level {
        case "Battery Optimized", "Performance Optimized":
            return 1
        case "Balanced":
            return 2
        case "Enhanced":
            return 3
        case "Full Effects":
            return 4
        default:
            return 0
        }
    }
}

#Preview {
    PerformanceSettingsView()
        .environmentObject(DeviceManager())
}