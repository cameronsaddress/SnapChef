# SnapChef AI Agents

A collection of specialized AI agents designed to accelerate SnapChef iOS app development. These agents are built following the [contains-studio/agents](https://github.com/contains-studio/agents) framework and optimized for Claude Code.

## 🚀 Quick Start

### Installation

```bash
# Clone this repository (if not already in your project)
cd /Users/cameronanderson/SnapChef/snapchef

# Install agents to Claude Code
./agents/install.sh

# Or manually copy to Claude's agent directory
cp -r agents/* ~/.claude/agents/
```

After installation, restart Claude Code for the agents to become available.

## 📦 Available Agents

### Engineering

#### `ios-swift-architect`
Expert in Swift 6, SwiftUI, and iOS architecture patterns. Specializes in MVVM implementation, CloudKit integration, and performance optimization.

**Use when:**
- Building new iOS features
- Implementing CloudKit sync
- Optimizing app performance
- Architecting SwiftUI views

#### `viral-video-engineer`
Specialist in video generation and social media optimization. Implements AVFoundation pipelines, effects, and platform-specific exports.

**Use when:**
- Creating TikTok/Instagram video features
- Optimizing video rendering
- Adding visual effects and transitions
- Implementing beat-synced animations

#### `ai-recipe-optimizer`
AI integration expert for recipe generation. Handles multiple LLM providers, prompt engineering, and response parsing.

**Use when:**
- Integrating new AI providers
- Optimizing prompts for better recipes
- Implementing vision API features
- Managing AI costs and performance

### Design

#### `swiftui-designer`
Creates beautiful, intuitive SwiftUI interfaces with custom animations and components.

**Use when:**
- Designing new UI components
- Implementing animations
- Creating custom gestures
- Building responsive layouts

#### `gamification-designer`
Designs engaging game mechanics, challenges, and reward systems to drive retention.

**Use when:**
- Creating challenge systems
- Implementing achievements
- Designing progression mechanics
- Building social competition features

### Marketing

#### `viral-content-strategist`
Optimizes features for viral growth and user-generated content across social platforms.

**Use when:**
- Implementing viral mechanics
- Creating shareable content
- Building influencer features
- Optimizing for platform algorithms

### Social Media

#### `tiktok-specialist`
Deep expertise in TikTok's algorithm, trends, and content formats.

**Use when:**
- Optimizing for TikTok
- Implementing TikTok-specific features
- Tracking FoodTok trends
- Creating viral video templates

### Testing

#### `ios-qa-engineer`
Ensures app quality through comprehensive testing, debugging, and performance profiling.

**Use when:**
- Writing test suites
- Debugging crashes
- Profiling performance
- Testing CloudKit integration

### Product

#### `feature-optimizer`
Uses data-driven approaches to optimize features, implement A/B tests, and improve metrics.

**Use when:**
- Analyzing feature performance
- Implementing A/B tests
- Optimizing user journeys
- Improving conversion rates

## 💡 Usage Examples

### Example 1: Building a New Feature
```
User: "I need to add a meal planning feature to the app"
Claude: "I'll help you build the meal planning feature. Let me use the ios-swift-architect agent to design the architecture and implement the core functionality."
```

### Example 2: Fixing Performance Issues
```
User: "The recipe list is scrolling slowly"
Claude: "I'll investigate the performance issue. Let me use the ios-qa-engineer agent to profile the app and identify bottlenecks."
```

### Example 3: Viral Growth
```
User: "We need more users sharing recipes on social media"
Claude: "I'll optimize for viral sharing. Let me use the viral-content-strategist agent to implement sharing incentives and the tiktok-specialist for platform-specific optimizations."
```

## 🏗️ Agent Structure

Each agent follows this structure:

```markdown
---
name: agent-name
description: When to use this agent with examples
color: visual-identifier
tools: Available tools for this agent
---

[Detailed system prompt with role, responsibilities, and expertise]
```

## 🛠️ Creating Custom Agents

To create a new agent:

1. Create a new `.md` file in the appropriate category folder
2. Follow the agent structure template
3. Include 3-4 usage examples in the description
4. Write a comprehensive system prompt (500+ words)
5. Run `./agents/install.sh` to install

## 📊 Agent Categories

- **Engineering**: Technical implementation and architecture
- **Design**: UI/UX and visual design
- **Marketing**: Growth and viral mechanics
- **Social Media**: Platform-specific optimization
- **Testing**: Quality assurance and debugging
- **Product**: Feature optimization and analytics

## 🔄 Updates

Agents are continuously improved based on:
- New iOS/Swift features
- Platform algorithm changes
- Emerging social media trends
- User feedback and metrics

## 📝 Best Practices

1. **Use agents proactively** - Claude will automatically select appropriate agents based on context
2. **Combine agents** - Multiple agents can work together on complex tasks
3. **Provide context** - Give agents relevant project information for better results
4. **Review output** - Agents provide suggestions; always review before implementing

## 🤝 Contributing

To contribute new agents or improvements:

1. Follow the existing agent structure
2. Test the agent with real scenarios
3. Document usage examples clearly
4. Ensure the agent is focused on a specific domain

## 📚 Resources

- [Contains Studio Agents](https://github.com/contains-studio/agents) - Original framework
- [Claude Code Docs](https://docs.anthropic.com/claude-code) - Official documentation
- [SnapChef iOS Guide](../ios/AI_DEVELOPER_GUIDE.md) - Project-specific guidance

## 🚨 Troubleshooting

If agents aren't appearing:
1. Ensure agents are in `~/.claude/agents/`
2. Restart Claude Code
3. Check file permissions
4. Verify `.md` file format

## 📄 License

These agents are part of the SnapChef project and follow the same licensing terms.