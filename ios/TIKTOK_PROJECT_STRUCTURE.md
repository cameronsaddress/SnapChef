# TikTok Viral Content Generation - Project Structure
*PM Agent - Complete Project Organization*
*Created: January 12, 2025*

## 🏗️ PROJECT ARCHITECTURE OVERVIEW

This document outlines the complete project structure for the TikTok viral content generation system, showing how all 8 agents will organize their work to deliver the requirements from `TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md`.

---

## 📁 CODE ORGANIZATION STRUCTURE

### Target Directory Structure
```
SnapChef/Features/Sharing/TikTok/
├── Engine/                           [CED Agent]
│   ├── ViralVideoEngine.swift       // Main entry point
│   ├── Planner.swift                // RenderPlan creation
│   ├── Renderer.swift               // AVFoundation compositor  
│   ├── StillWriter.swift            // Image→video conversion
│   └── AudioBeatDetector.swift      // Beat detection (stub)
│
├── Models/                           [CED Agent]
│   ├── Recipe+Video.swift           // Recipe extension with video properties
│   ├── MediaBundle.swift            // Image and video assets
│   ├── RenderConfig.swift           // Configuration with safe zones
│   └── RenderPlan.swift             // TrackItem and Overlay structures
│
├── Overlays/                         [OAS Agent]
│   ├── OverlayFactory.swift         // All overlay creation methods
│   ├── TextStyles.swift             // Typography and text styling
│   ├── Animations.swift             // Spring, drop, pop animations
│   └── SafeZones.swift              // Safe zone validation
│
├── Templates/                        [TD1 & TD2 Agents]
│   ├── BeatSyncedCarousel.swift     // Template 1 [TD1]
│   ├── SplitScreenSwipe.swift       // Template 2 [TD1] 
│   ├── KineticSteps.swift           // Template 3 [TD1]
│   ├── PriceTimeChallenge.swift     // Template 4 [TD2]
│   └── GreenScreenPIP.swift         // Template 5 [TD2]
│
├── Effects/                          [TD2 Agent]
│   ├── Filters.swift                // CIColorControls, CIGaussianBlur
│   ├── Transforms.swift             // Ken Burns, scaling, transitions
│   └── Transitions.swift            // Circular wipe, reveals
│
├── Sharing/                          [SSI Agent]
│   ├── ShareService.swift           // Core sharing functionality
│   ├── TikTokIntegration.swift      // SDK integration and URL handling
│   ├── CaptionGenerator.swift       // Dynamic caption creation
│   └── PhotoLibraryManager.swift    // Photos framework integration
│
└── Tests/                            [QAT Agent]
    ├── EngineTests.swift             // Core engine testing
    ├── TemplateTests.swift           // All template testing
    ├── ShareTests.swift              // Sharing flow testing
    ├── PerformanceTests.swift        // Performance benchmarks
    └── TestData/                     // Test recipes and media
        ├── TestRecipes.swift
        └── TestImages/
```

---

## 🎯 AGENT RESPONSIBILITIES & DELIVERABLES

### 🏗️ CED - Core Engine Developer
**Files to Create/Modify**: 8 core files
**Primary Deliverables**:
- Complete data model system
- ViralVideoEngine main class
- AVFoundation-based Renderer
- Image-to-video StillWriter
- Export pipeline with H.264/AAC

**Key Interfaces for Other Agents**:
```swift
// For TD1/TD2 (Template developers)
protocol ViralTemplate {
    func createRenderPlan(recipe: Recipe, media: MediaBundle, config: RenderConfig) -> RenderPlan
}

// For OAS (Overlay specialist)
public struct RenderPlan {
    public let overlays: [Overlay]
    // Overlay system integration points
}
```

### 🎨 OAS - Overlay & Animation Specialist  
**Files to Create**: 4 overlay system files
**Primary Deliverables**:
- Complete OverlayFactory with all text methods
- Safe zone validation system
- All animation types (spring, drop, pop)
- Typography system meeting exact specifications

**Key Interfaces for Other Agents**:
```swift
// For TD1/TD2 (Template developers)
enum OverlayFactory {
    static func heroHookOverlay(text: String, config: RenderConfig) -> Overlay
    static func ctaOverlay(text: String, config: RenderConfig) -> Overlay
    static func ingredientCallout(ingredients: [String], config: RenderConfig) -> Overlay
    // All other overlay methods
}
```

### 📹 TD1 - Template Developer 1 (Templates 1-3)
**Files to Create**: 3 template files  
**Primary Deliverables**:
- Template 1: Beat-Synced Photo Carousel
- Template 2: Split-Screen "Swipe" Before/After
- Template 3: Kinetic-Text "Recipe in 5 Steps"

**Dependencies**: CED (engine) + OAS (overlays)

### 🎬 TD2 - Template Developer 2 (Templates 4-5 + Effects)
**Files to Create**: 5 files (2 templates + 3 effects)
**Primary Deliverables**:
- Template 4: "Price & Time Challenge" Sticker Pack  
- Template 5: Green-Screen "My Fridge → My Plate" (PIP)
- Complete effects system (filters, transforms, transitions)

**Dependencies**: CED (engine) + OAS (overlays)

### 📱 SSI - ShareService & SDK Integrator
**Files to Create/Modify**: 4 sharing files + app configuration
**Primary Deliverables**:
- Complete ShareService implementation
- TikTok SDK integration with sandbox credentials
- Photo library permissions and save functionality
- Caption generation and clipboard handling
- App delegate URL scheme handling

**App Configuration Changes**:
- Info.plist updates for TikTok SDK
- URL scheme handlers
- Photo library usage description

### 🧪 QAT - Quality Assurance & Testing
**Files to Create**: 5+ test files
**Primary Deliverables**:
- Comprehensive test suite for all components
- Performance benchmarking tests
- Device compatibility validation
- Test data (recipes, images, scenarios)
- Quality checklist automation

**Testing Coverage**:
- All 5 templates with various recipe types
- Share flow end-to-end testing
- Performance and memory validation
- Error handling verification

### 📊 PAP - Performance & Polish
**No new files created** - focuses on optimization
**Primary Deliverables**:
- Memory usage optimization (<150MB)
- Render time optimization (<5 seconds)  
- File size optimization (<20MB average)
- Performance monitoring and profiling
- Final polish and error recovery

---

## 🔗 INTEGRATION POINTS

### Component Integration Flow
```
1. Recipe Data Input
   ↓
2. CED: ViralVideoEngine.render(template, recipe, media)
   ↓
3. Template: Creates RenderPlan with overlays
   ↓
4. OAS: Generates all overlay layers
   ↓  
5. CED: Renderer composites video
   ↓
6. SSI: Saves to Photos → Shares to TikTok
```

### Data Flow Between Agents
```
User Input → Recipe + MediaBundle
    ↓
CED: Processes through ViralVideoEngine
    ↓
TD1/TD2: Template creates RenderPlan
    ↓
OAS: Adds overlays to RenderPlan  
    ↓
CED: Renderer exports video file
    ↓
SSI: ShareService handles sharing
    ↓
QAT: Validates entire flow
    ↓
PAP: Monitors performance
```

---

## ⚙️ CONFIGURATION & SETUP

### Required App Configuration (SSI Agent)
```swift
// Info.plist additions
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktokopensdk</string>
    <string>tiktoksharesdk</string>
    <string>snssdk1180</string>
    <string>snssdk1233</string>
</array>

<key>TikTokClientKey</key>
<string>sbawj0946ft24i4wjv</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>SnapChef needs access to save your recipe videos for sharing</string>
```

### Performance Targets (PAP Agent)
```swift
// Target specifications to achieve
let performanceTargets = PerformanceTargets(
    renderTime: 5.0,        // seconds
    memoryPeak: 150.0,      // MB
    fileSizeAverage: 20.0,  // MB
    frameRate: 30,          // fps
    successRate: 0.99       // 99%
)
```

### Safe Zone Specifications (OAS Agent)
```swift
// Exact safe zone requirements
let safeInsets = UIEdgeInsets(
    top: 192,     // 10% of 1920px height
    left: 72,     // Left margin
    bottom: 192,  // 10% of 1920px height
    right: 72     // Right margin
)
```

---

## 📋 QUALITY REQUIREMENTS

### Code Quality Standards (All Agents)
1. **No compiler warnings** - Clean build required
2. **Memory leak prevention** - Use autoreleasepool for frame processing
3. **Error handling** - All failure cases must be handled
4. **Documentation** - Public methods must be documented
5. **Testing** - Components must be testable

### Performance Requirements (PAP Agent Focus)
1. **Render time <5 seconds** for 15-second video
2. **Memory usage <150MB** during rendering
3. **File size <20MB** average output
4. **30 FPS constant** playback
5. **>99% success rate** for exports

### Template Quality Requirements (TD1/TD2 Agents)
1. **Safe zone compliance** - No text outside margins
2. **Timing accuracy** - Exact durations per template
3. **Animation smoothness** - No stutters or glitches
4. **Dynamic text handling** - All Recipe properties work
5. **Visual polish** - Production-quality appearance

---

## 🚀 DEPLOYMENT STRATEGY

### Phase 1: Foundation (Hours 0-8)
**Goal**: Core components operational
**Deliverables**: CED + OAS + SSI foundation ready
**Success Criteria**: Templates can begin development

### Phase 2: Template Development (Hours 8-16)  
**Goal**: First templates working
**Deliverables**: Templates 1 & 4 operational
**Success Criteria**: End-to-end video generation works

### Phase 3: Complete Implementation (Hours 16-24)
**Goal**: All templates operational
**Deliverables**: All 5 templates + effects system
**Success Criteria**: Full feature set working

### Phase 4: Integration & Testing (Hours 24-32)
**Goal**: Production-ready system
**Deliverables**: Complete testing + optimization
**Success Criteria**: All quality gates passed

### Phase 5: Final Validation (Hours 32-40)
**Goal**: Ship-ready deliverable
**Deliverables**: Final polish + approval
**Success Criteria**: PM final sign-off

---

## 📊 SUCCESS METRICS

### Technical Metrics
- **Functionality**: All 5 templates render correctly ✅
- **Performance**: All targets met (<5s, <150MB, <20MB) ✅
- **Quality**: Clean build, no memory leaks ✅
- **Integration**: ShareService complete flow works ✅

### User Experience Metrics  
- **Ease of Use**: Simple template selection and sharing ✅
- **Visual Appeal**: Professional, viral-ready videos ✅
- **Reliability**: Consistent rendering without crashes ✅
- **Speed**: Fast generation encourages usage ✅

### Business Metrics (Post-Launch)
- **Engagement**: >80% video completion rate
- **Virality**: >10% like rate, >2% share rate
- **Usage**: Template selection distribution
- **Success**: Share completion rate >90%

---

## 🎯 PROJECT SUCCESS DEFINITION

The TikTok viral content generation project will be considered successful when:

1. ✅ **All 5 viral templates** render beautiful, engaging videos
2. ✅ **Complete ShareService integration** saves and shares to TikTok seamlessly  
3. ✅ **Performance targets achieved** (<5s render, <150MB memory, <20MB files)
4. ✅ **Quality standards met** (safe zones, smooth animations, no bugs)
5. ✅ **Integration complete** with existing SnapChef app
6. ✅ **Testing validated** across all supported devices
7. ✅ **Documentation complete** for maintenance and future development

When all criteria are met, the PM agent will provide final approval and the system will be ready for user testing and production deployment.

---

*This structure ensures all 8 agents work efficiently together to deliver a production-quality TikTok viral content generation system that meets every requirement specified in the original documentation.*