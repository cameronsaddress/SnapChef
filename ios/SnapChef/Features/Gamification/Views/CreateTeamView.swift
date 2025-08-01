import SwiftUI

struct CreateTeamView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var teamManager = TeamChallengeManager.shared
    
    @State private var teamName = ""
    @State private var teamDescription = ""
    @State private var selectedIcon = "🍕"
    @State private var selectedColor = Color(hex: "#667eea")
    @State private var isPrivate = false
    @State private var weeklyGoal = 1000
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let teamIcons = ["🍕", "🍔", "🌮", "🍜", "🥗", "🍳", "🥘", "🍱", "🥙", "🍛", "🍝", "🥪"]
    let teamColors = [
        Color(hex: "#667eea"),
        Color(hex: "#764ba2"),
        Color(hex: "#f093fb"),
        Color(hex: "#4facfe"),
        Color(hex: "#43e97b"),
        Color(hex: "#fa709a"),
        Color(hex: "#feca57"),
        Color(hex: "#ff6b6b")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                MagicalBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Team Icon Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose an Icon")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                                ForEach(teamIcons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        Text(icon)
                                            .font(.largeTitle)
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.gray.opacity(0.1))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedIcon == icon ? selectedColor : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Team Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Team Name")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter team name", text: $teamName)
                                .textFieldStyle(GlassmorphicTextFieldStyle())
                        }
                        
                        // Team Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("What's your team about?", text: $teamDescription)
                                .textFieldStyle(GlassmorphicTextFieldStyle())
                        }
                        
                        // Team Color
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Team Color")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                ForEach(teamColors, id: \.self) { color in
                                    Button(action: { selectedColor = color }) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Weekly Goal
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Goal")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("\(weeklyGoal) points")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Stepper("", value: $weeklyGoal, in: 500...10000, step: 500)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        
                        // Privacy Toggle
                        Toggle(isOn: $isPrivate) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Private Team")
                                    .font(.headline)
                                
                                Text("Only members with the join code can join")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                        
                        // Create Button
                        Button(action: createTeam) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Team")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .disabled(teamName.isEmpty || isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createTeam() {
        guard !teamName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                try await teamManager.createTeam(
                    name: teamName,
                    description: teamDescription,
                    icon: selectedIcon,
                    color: selectedColor,
                    isPrivate: isPrivate,
                    weeklyGoal: weeklyGoal
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Join Team View
struct JoinTeamView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var teamManager = TeamChallengeManager.shared
    
    let team: Team?
    @Binding var joinCode: String
    @State private var isJoining = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                MagicalBackground()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    if let team = team {
                        // Joining specific team
                        VStack(spacing: 24) {
                            Text(team.imageIcon)
                                .font(.system(size: 80))
                            
                            Text("Join \(team.name)?")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(team.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                Label("\(team.members.count) members", systemImage: "person.2.fill")
                                Label("\(team.weeklyPoints) weekly points", systemImage: "star.fill")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    } else {
                        // Joining with code
                        VStack(spacing: 24) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "#667eea"))
                            
                            Text("Enter Team Code")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            TextField("Team code", text: $joinCode)
                                .textFieldStyle(GlassmorphicTextFieldStyle())
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                    
                    // Join Button
                    Button(action: joinTeam) {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Join Team")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .disabled(isJoining || (team == nil && joinCode.isEmpty))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Join Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func joinTeam() {
        isJoining = true
        
        Task {
            do {
                if let team = team {
                    try await teamManager.joinTeam(team.id)
                } else {
                    try await teamManager.joinTeamWithCode(joinCode)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isJoining = false
                }
            }
        }
    }
}

// MARK: - Team Details View
struct TeamDetailsView: View {
    let team: Team
    @Environment(\.dismiss) var dismiss
    @StateObject private var teamManager = TeamChallengeManager.shared
    @State private var showLeaveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                MagicalBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Team Header
                        VStack(spacing: 16) {
                            Text(team.imageIcon)
                                .font(.system(size: 80))
                            
                            Text(team.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(team.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Join Code: \(team.joinCode)")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#667eea"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#667eea").opacity(0.1))
                                )
                        }
                        .padding()
                        
                        // Team Stats
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            TeamStatCard(title: "Total Points", value: "\(team.totalPoints)", icon: "star.fill")
                            TeamStatCard(title: "Weekly Points", value: "\(team.weeklyPoints)", icon: "calendar")
                            TeamStatCard(title: "Members", value: "\(team.members.count)", icon: "person.2.fill")
                            TeamStatCard(title: "Challenges", value: "\(team.completedChallenges)", icon: "flag.fill")
                        }
                        .padding(.horizontal)
                        
                        // Members List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Team Members")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(team.members, id: \.self) { memberId in
                                    TeamMemberRow(memberId: memberId)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Leave Team Button
                        Button(action: { showLeaveConfirmation = true }) {
                            Text("Leave Team")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Team Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Leave Team?", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        try? await teamManager.leaveCurrentTeam()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to leave \(team.name)?")
            }
        }
    }
}

// MARK: - Helper Views
struct TeamStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: "#667eea"))
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct TeamMemberRow: View {
    let memberId: String
    
    var body: some View {
        GlassmorphicCard {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#667eea"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(memberId) // In real app, fetch member name
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Active today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("250 pts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#667eea"))
            }
            .padding()
        }
    }
}

// MARK: - Full Team Leaderboard View
struct FullTeamLeaderboardView: View {
    @StateObject private var teamManager = TeamChallengeManager.shared
    @State private var timeRange: TeamLeaderboardTimeRange = .weekly
    
    enum TeamLeaderboardTimeRange: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case allTime = "All Time"
    }
    
    var body: some View {
        ZStack {
            MagicalBackground()
            
            VStack {
                // Time Range Picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TeamLeaderboardTimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Leaderboard List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(teamManager.topTeams.enumerated()), id: \.element.id) { index, team in
                            TeamLeaderboardRow(team: team, rank: index + 1)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Team Leaderboard")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Text Field Style
struct GlassmorphicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Preview
struct CreateTeamView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CreateTeamView()
            JoinTeamView(team: nil, joinCode: .constant(""))
        }
    }
}