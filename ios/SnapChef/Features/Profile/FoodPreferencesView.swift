import SwiftUI

struct FoodPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedCuisines: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? [])
    @State private var showSaveAnimation = false
    
    let cuisineTypes = [
        ("Italian", "🍝"),
        ("Mexican", "🌮"),
        ("Chinese", "🥡"),
        ("Japanese", "🍱"),
        ("Thai", "🍜"),
        ("Indian", "🍛"),
        ("American", "🍔"),
        ("Mediterranean", "🥙"),
        ("French", "🥐"),
        ("Korean", "🍖"),
        ("Vietnamese", "🍲"),
        ("Greek", "🥗"),
        ("Spanish", "🥘"),
        ("Middle Eastern", "🧆"),
        ("Caribbean", "🌴"),
        ("African", "🍖"),
        ("British", "🇬🇧"),
        ("German", "🥨"),
        ("Brazilian", "🇧🇷"),
        ("Peruvian", "🌽"),
        ("Vegetarian", "🥬"),
        ("Vegan", "🌱"),
        ("Seafood", "🦞"),
        ("BBQ", "🔥"),
        ("Comfort Food", "🍗"),
        ("Healthy", "🥗"),
        ("Desserts", "🍰"),
        ("Breakfast", "🥞")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("🍳")
                                .font(.system(size: 60))
                            
                            Text("What's Your Flavor?")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Select cuisines you love and we'll craft recipes just for you!")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            if !selectedCuisines.isEmpty {
                                Text("\(selectedCuisines.count) selected")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.top, 20)
                        
                        // Cuisine Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(cuisineTypes, id: \.0) { cuisine, emoji in
                                CuisineCard(
                                    name: cuisine,
                                    emoji: emoji,
                                    isSelected: selectedCuisines.contains(cuisine),
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedCuisines.contains(cuisine) {
                                                selectedCuisines.remove(cuisine)
                                            } else {
                                                selectedCuisines.insert(cuisine)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom Save Button
                VStack {
                    Spacer()
                    
                    Button(action: savePreferences) {
                        HStack {
                            Text("Save My Tastes")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Image(systemName: showSaveAnimation ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .font(.system(size: 24))
                                .scaleEffect(showSaveAnimation ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSaveAnimation)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#ff6b6b"),
                                            Color(hex: "#ff8787")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color(hex: "#ff6b6b").opacity(0.3), radius: 20, y: 10)
                        )
                        .scaleEffect(showSaveAnimation ? 1.05 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .disabled(selectedCuisines.isEmpty)
                    .opacity(selectedCuisines.isEmpty ? 0.5 : 1)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select All") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if selectedCuisines.count == cuisineTypes.count {
                                selectedCuisines.removeAll()
                            } else {
                                selectedCuisines = Set(cuisineTypes.map { $0.0 })
                            }
                        }
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }
    
    private func savePreferences() {
        // Save to UserDefaults
        UserDefaults.standard.set(Array(selectedCuisines), forKey: "SelectedFoodPreferences")
        
        // Show save animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSaveAnimation = true
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

struct CuisineCard: View {
    let name: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 40))
                    .scaleEffect(isSelected ? 1.2 : 1)
                
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                Color(hex: "#ff6b6b"),
                                Color(hex: "#ff8787")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? Color.clear : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .shadow(
                color: isSelected ? Color(hex: "#ff6b6b").opacity(0.3) : Color.clear,
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    FoodPreferencesView()
}