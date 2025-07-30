import SwiftUI

struct AIPersonalityView: View {
    @StateObject private var personalityManager = AIPersonalityManager.shared
    @State private var selectedPersona: AIChefPersona?
    @State private var showingPersonaDetail = false
    @State private var showingSurpriseSettings = false
    @State private var contentVisible = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        PersonalityHeaderView(currentPersona: personalityManager.currentPersona)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .staggeredFade(index: 0, isShowing: contentVisible)
                        
                        // Current persona showcase
                        CurrentPersonaCard(
                            persona: personalityManager.currentPersona,
                            onTap: {
                                selectedPersona = personalityManager.currentPersona
                                showingPersonaDetail = true
                            }
                        )
                        .padding(.horizontal, 20)
                        .staggeredFade(index: 1, isShowing: contentVisible)
                        
                        // Surprise settings
                        SurpriseSettingsCard(
                            settings: personalityManager.surpriseSettings,
                            onTap: { showingSurpriseSettings = true }
                        )
                        .padding(.horizontal, 20)
                        .staggeredFade(index: 2, isShowing: contentVisible)
                        
                        // Available personas
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Choose Your Chef")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ],
                                spacing: 16
                            ) {
                                ForEach(Array(personalityManager.allPersonas.enumerated()), id: \.element.id) { index, persona in
                                    PersonaCard(
                                        persona: persona,
                                        isUnlocked: personalityManager.unlockedPersonas.contains(persona.id),
                                        isCurrent: persona.id == personalityManager.currentPersona.id,
                                        onTap: {
                                            selectedPersona = persona
                                            showingPersonaDetail = true
                                        }
                                    )
                                    .staggeredFade(
                                        index: index + 3,
                                        isShowing: contentVisible
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("AI Personality")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPersonaDetail) {
            if let persona = selectedPersona {
                PersonaDetailView(
                    persona: persona,
                    isUnlocked: personalityManager.unlockedPersonas.contains(persona.id),
                    onSelect: {
                        personalityManager.selectPersona(persona)
                        showingPersonaDetail = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSurpriseSettings) {
            SurpriseSettingsView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
        }
    }
}

// MARK: - Personality Header
struct PersonalityHeaderView: View {
    let currentPersona: AIChefPersona
    @State private var messageRotation = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your AI Chef")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Customize your cooking companion")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Animated chat bubble
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: currentPersona.color).opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: currentPersona.color), lineWidth: 2)
                        )
                        .rotationEffect(.degrees(messageRotation))
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(Color(hex: currentPersona.color))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                messageRotation = 10
            }
        }
    }
}

// MARK: - Current Persona Card
struct CurrentPersonaCard: View {
    let persona: AIChefPersona
    let onTap: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard {
                VStack(spacing: 20) {
                    HStack {
                        Text("Currently Active")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: persona.color))
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "#43e97b"))
                    }
                    
                    HStack(spacing: 20) {
                        // Persona emoji
                        Text(persona.emoji)
                            .font(.system(size: 60))
                            .scaleEffect(isAnimating ? 1.1 : 1)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(persona.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(persona.personality.description)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                            
                            // Voice style badge
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 12, weight: .medium))
                                Text(persona.voiceStyle.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: persona.color).opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: persona.color), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Spacer()
                    }
                    
                    // Sample phrase
                    Text("\"\(persona.catchPhrases.randomElement() ?? "")\"")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Surprise Settings Card
struct SurpriseSettingsCard: View {
    let settings: SurpriseRecipeSettings
    let onTap: () -> Void
    @State private var sparkleAnimation = false
    
    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard {
                HStack(spacing: 16) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#f093fb").opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Text("🎲")
                            .font(.system(size: 32))
                            .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mystery Meal Settings")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            // Status
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(settings.isEnabled ? Color(hex: "#43e97b") : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(settings.isEnabled ? "Enabled" : "Disabled")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Wildness level
                            Text("•")
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(settings.wildnessLevel.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(settings.wildnessLevel.color)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
            }
        }
    }
}

// MARK: - Persona Card
struct PersonaCard: View {
    let persona: AIChefPersona
    let isUnlocked: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard {
                VStack(spacing: 16) {
                    // Lock overlay
                    ZStack {
                        // Emoji or lock
                        Text(isUnlocked ? persona.emoji : "🔒")
                            .font(.system(size: 50))
                            .opacity(isUnlocked ? 1 : 0.5)
                        
                        // Current indicator
                        if isCurrent {
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#43e97b"))
                                        .background(Circle().fill(Color.black))
                                        .offset(x: 10, y: -10)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 60)
                    
                    VStack(spacing: 8) {
                        Text(persona.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isUnlocked ? 1 : 0.7)
                        
                        Text(persona.personality.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: persona.color))
                            .opacity(isUnlocked ? 1 : 0.5)
                        
                        if !isUnlocked, let requirement = persona.unlockRequirement {
                            Text(requirement)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .overlay(
                    isCurrent ?
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: persona.color), lineWidth: 2)
                    : nil
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Persona Detail View
struct PersonaDetailView: View {
    let persona: AIChefPersona
    let isUnlocked: Bool
    let onSelect: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var emojiScale: CGFloat = 0
    @State private var showUnlockAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Persona emoji with animation
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: persona.color).opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            Text(isUnlocked ? persona.emoji : "🔒")
                                .font(.system(size: 80))
                                .scaleEffect(emojiScale)
                                .opacity(isUnlocked ? 1 : 0.5)
                        }
                        .padding(.top, 40)
                        
                        // Name and personality
                        VStack(spacing: 16) {
                            Text(persona.name)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(persona.personality.description)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        // Voice style
                        VoiceStyleCard(voiceStyle: persona.voiceStyle, color: persona.color)
                            .padding(.horizontal, 20)
                        
                        // Specialties
                        SpecialtiesCard(specialties: persona.specialties, color: persona.color)
                            .padding(.horizontal, 20)
                        
                        // Catch phrases
                        CatchPhrasesCard(phrases: persona.catchPhrases, color: persona.color)
                            .padding(.horizontal, 20)
                        
                        // Action button
                        if isUnlocked {
                            MagneticButton(
                                title: "Select This Chef",
                                icon: "checkmark.circle.fill",
                                action: onSelect
                            )
                            .padding(.horizontal, 20)
                        } else {
                            LockedPersonaCard(requirement: persona.unlockRequirement ?? "Complete challenges to unlock")
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                emojiScale = 1
            }
        }
    }
}

// MARK: - Voice Style Card
struct VoiceStyleCard: View {
    let voiceStyle: AIChefPersona.VoiceStyle
    let color: String
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: color))
                    
                    Text("Voice Style")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text(voiceStyle.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: color).opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: color), lineWidth: 1)
                            )
                    )
            }
            .padding(20)
        }
    }
}

// MARK: - Specialties Card
struct SpecialtiesCard: View {
    let specialties: [String]
    let color: String
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: color))
                    
                    Text("Specialties")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(specialties, id: \.self) { specialty in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 6, height: 6)
                            
                            Text(specialty)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Catch Phrases Card
struct CatchPhrasesCard: View {
    let phrases: [String]
    let color: String
    @State private var currentPhraseIndex = 0
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: color))
                    
                    Text("Signature Phrases")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Rotating phrases
                Text("\"\(phrases[currentPhraseIndex])\"")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .id(currentPhraseIndex)
                
                // Dots indicator
                HStack(spacing: 8) {
                    ForEach(0..<phrases.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPhraseIndex ? Color(hex: color) : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                withAnimation {
                    currentPhraseIndex = (currentPhraseIndex + 1) % phrases.count
                }
            }
        }
    }
}

// MARK: - Locked Persona Card
struct LockedPersonaCard: View {
    let requirement: String
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Locked")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(requirement)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

// MARK: - Surprise Settings View
struct SurpriseSettingsView: View {
    @StateObject private var personalityManager = AIPersonalityManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var wildnessLevel: SurpriseRecipeSettings.WildnessLevel
    @State private var isEnabled: Bool
    @State private var selectedCuisines: Set<String>
    
    init() {
        let settings = AIPersonalityManager.shared.surpriseSettings
        _wildnessLevel = State(initialValue: settings.wildnessLevel)
        _isEnabled = State(initialValue: settings.isEnabled)
        _selectedCuisines = State(initialValue: settings.allowedCuisines)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 16) {
                            Text("🎲")
                                .font(.system(size: 80))
                            
                            Text("Mystery Meal Settings")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Configure your culinary surprises")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 40)
                        
                        // Enable toggle
                        GlassmorphicCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Enable Mystery Meals")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Add surprise elements to recipes")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isEnabled)
                                    .tint(Color(hex: "#43e97b"))
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 20)
                        
                        // Wildness level
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Surprise Level")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(SurpriseRecipeSettings.WildnessLevel.allCases, id: \.self) { level in
                                    WildnessLevelCard(
                                        level: level,
                                        isSelected: wildnessLevel == level,
                                        onTap: { wildnessLevel = level }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .opacity(isEnabled ? 1 : 0.5)
                        .disabled(!isEnabled)
                        
                        // Cuisine preferences
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Allowed Cuisines")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 12
                            ) {
                                ForEach(Cuisine.allCases, id: \.self) { cuisine in
                                    CuisineToggle(
                                        cuisine: cuisine.rawValue,
                                        isSelected: selectedCuisines.contains(cuisine.rawValue),
                                        onToggle: {
                                            if selectedCuisines.contains(cuisine.rawValue) {
                                                selectedCuisines.remove(cuisine.rawValue)
                                            } else {
                                                selectedCuisines.insert(cuisine.rawValue)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .opacity(isEnabled ? 1 : 0.5)
                        .disabled(!isEnabled)
                        
                        // Save button
                        MagneticButton(
                            title: "Save Settings",
                            icon: "checkmark.circle.fill",
                            action: saveSettings
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
    }
    
    private func saveSettings() {
        personalityManager.surpriseSettings.isEnabled = isEnabled
        personalityManager.surpriseSettings.wildnessLevel = wildnessLevel
        personalityManager.surpriseSettings.allowedCuisines = selectedCuisines
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}

// MARK: - Wildness Level Card
struct WildnessLevelCard: View {
    let level: SurpriseRecipeSettings.WildnessLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var emoji: String {
        switch level {
        case .mild: return "😊"
        case .medium: return "😎"
        case .wild: return "🤪"
        case .insane: return "🤯"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard {
                HStack(spacing: 16) {
                    Text(emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(level.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? level.color : .white.opacity(0.3))
                }
                .padding(16)
            }
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(level.color, lineWidth: 2)
                : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Cuisine Toggle
struct CuisineToggle: View {
    let cuisine: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(cuisine)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                                ? Color(hex: "#667eea")
                                : Color.white.opacity(0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.clear : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AIPersonalityView()
}