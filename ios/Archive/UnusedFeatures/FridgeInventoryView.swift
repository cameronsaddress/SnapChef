import SwiftUI

struct FridgeInventoryView: View {
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCategory: String? = nil
    @State private var animateItems = false
    @State private var showingImage = false
    
    // Group ingredients by category
    var categorizedIngredients: [String: [IngredientAPI]] {
        Dictionary(grouping: ingredients, by: { $0.category })
    }
    
    var categoryColors: [String: Color] {
        [
            "Fruits": Color(hex: "#43e97b"),
            "Vegetables": Color(hex: "#38f9d7"),
            "Dairy": Color(hex: "#4facfe"),
            "Proteins": Color(hex: "#f093fb"),
            "Grains": Color(hex: "#ffa726"),
            "Condiments": Color(hex: "#667eea"),
            "Beverages": Color(hex: "#ef5350"),
            "Other": Color(hex: "#764ba2")
        ]
    }
    
    var categoryEmojis: [String: String] {
        [
            "Fruits": "🍎",
            "Vegetables": "🥬",
            "Dairy": "🥛",
            "Proteins": "🥩",
            "Grains": "🌾",
            "Condiments": "🧂",
            "Beverages": "🥤",
            "Other": "📦"
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header with fridge photo option
                        FridgeHeaderView(
                            totalItems: ingredients.count,
                            showPhoto: capturedImage != nil,
                            onPhotoTap: {
                                showingImage = true
                            }
                        )
                        .padding(.top, 20)
                        
                        // Category filter pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                CategoryPill(
                                    title: "All",
                                    emoji: "🎯",
                                    isSelected: selectedCategory == nil,
                                    color: Color(hex: "#667eea")
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = nil
                                    }
                                }
                                
                                ForEach(Array(categorizedIngredients.keys.sorted()), id: \.self) { category in
                                    CategoryPill(
                                        title: category,
                                        emoji: categoryEmojis[category] ?? "📦",
                                        isSelected: selectedCategory == category,
                                        color: categoryColors[category] ?? Color.gray
                                    ) {
                                        withAnimation(.spring()) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Ingredients grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            let filteredIngredients = selectedCategory == nil 
                                ? ingredients 
                                : ingredients.filter { $0.category == selectedCategory }
                            
                            ForEach(Array(filteredIngredients.enumerated()), id: \.element.name) { index, ingredient in
                                IngredientCard(
                                    ingredient: ingredient,
                                    color: categoryColors[ingredient.category] ?? Color.gray,
                                    emoji: categoryEmojis[ingredient.category] ?? "📦"
                                )
                                .scaleEffect(animateItems ? 1 : 0.8)
                                .opacity(animateItems ? 1 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.7)
                                        .delay(Double(index) * 0.05),
                                    value: animateItems
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Fun stats section
                        FridgeStatsView(ingredients: ingredients)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Your Fridge Inventory")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateItems = true
            }
        }
        .sheet(isPresented: $showingImage) {
            if let image = capturedImage {
                ImageViewerSheet(image: image)
            }
        }
    }
}

// MARK: - Fridge Header View
struct FridgeHeaderView: View {
    let totalItems: Int
    let showPhoto: Bool
    let onPhotoTap: () -> Void
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Animated fridge icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#38f9d7").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseAnimation ? 1.2 : 1)
                
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#38f9d7"),
                                Color(hex: "#43e97b")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Found \(totalItems) ingredients!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#38f9d7"),
                            Color(hex: "#43e97b")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            if showPhoto {
                Button(action: onPhotoTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                        Text("View Original Photo")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(color, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
    }
}

// MARK: - Ingredient Card
struct IngredientCard: View {
    let ingredient: IngredientAPI
    let color: Color
    let emoji: String
    
    @State private var isPressed = false
    
    var freshnessColor: Color {
        switch ingredient.freshness.lowercased() {
        case "fresh": return Color(hex: "#43e97b")
        case "good": return Color(hex: "#38f9d7")
        case "use soon": return Color(hex: "#ffa726")
        case "expired": return Color(hex: "#ef5350")
        default: return Color.gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with emoji
            HStack {
                Text(emoji)
                    .font(.system(size: 24))
                
                Spacer()
                
                // Freshness indicator
                Circle()
                    .fill(freshnessColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(freshnessColor)
                            .frame(width: 16, height: 16)
                            .opacity(0.3)
                    )
            }
            
            // Ingredient name
            Text(ingredient.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            // Quantity
            Text("\(ingredient.quantity) \(ingredient.unit)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            // Freshness tag
            Text(ingredient.freshness)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(freshnessColor.opacity(0.8))
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Fridge Stats View
struct FridgeStatsView: View {
    let ingredients: [IngredientAPI]
    
    var freshnessStats: [String: Int] {
        Dictionary(grouping: ingredients, by: { $0.freshness })
            .mapValues { $0.count }
    }
    
    var topCategories: [(String, Int)] {
        Dictionary(grouping: ingredients, by: { $0.category })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎊 Fun Fridge Facts")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Freshness overview
            GlassmorphicCard(content: {
                VStack(spacing: 16) {
                    Text("Freshness Overview")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        if let fresh = freshnessStats["Fresh"] {
                            StatBubble(
                                value: "\(fresh)",
                                label: "Fresh",
                                color: Color(hex: "#43e97b")
                            )
                        }
                        
                        if let good = freshnessStats["Good"] {
                            StatBubble(
                                value: "\(good)",
                                label: "Good",
                                color: Color(hex: "#38f9d7")
                            )
                        }
                        
                        if let useSoon = freshnessStats["Use Soon"] {
                            StatBubble(
                                value: "\(useSoon)",
                                label: "Use Soon",
                                color: Color(hex: "#ffa726")
                            )
                        }
                    }
                }
                .padding(20)
            }, glowColor: Color(hex: "#38f9d7"))
            
            // Top categories
            GlassmorphicCard(content: {
                VStack(spacing: 16) {
                    Text("Top Categories")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    ForEach(topCategories, id: \.0) { category, count in
                        HStack {
                            Text(category)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(count) items")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#38f9d7"))
                        }
                    }
                }
                .padding(20)
            }, glowColor: Color(hex: "#667eea"))
        }
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Image Viewer Sheet
struct ImageViewerSheet: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
    }
}

#Preview {
    FridgeInventoryView(
        ingredients: [
            IngredientAPI(
                name: "Tomatoes",
                quantity: "4",
                unit: "pieces",
                category: "Vegetables",
                freshness: "Fresh",
                location: nil
            ),
            IngredientAPI(
                name: "Milk",
                quantity: "1",
                unit: "liter",
                category: "Dairy",
                freshness: "Good",
                location: nil
            )
        ],
        capturedImage: nil
    )
}