# SnapChef Workspace Structure

This workspace contains multiple repositories for the SnapChef project. Each repository is managed independently with its own Git history.

## Repository Structure

```
/Users/cameronanderson/
├── SnapChef/snapchef/ios/        # iOS App Repository
│   └── .git/                     # Git repo: https://github.com/cameronsaddress/snapchef
│
└── snapchef-server/snapchef-server/  # FastAPI Server Repository
    └── .git/                         # Git repo: https://github.com/cameronsaddress/snapchef-server
```

## Important Notes

### Working with Multiple Repositories

1. **Always check your current directory** before running Git commands:
   ```bash
   pwd  # Shows current directory
   ```

2. **iOS Repository** (Frontend):
   - Path: `/Users/cameronanderson/SnapChef/snapchef/ios/`
   - GitHub: https://github.com/cameronsaddress/snapchef
   - Default branch: `main`
   - Language: Swift/SwiftUI
   - Purpose: iOS mobile app

3. **Server Repository** (Backend):
   - Path: `/Users/cameronanderson/snapchef-server/snapchef-server/`
   - GitHub: https://github.com/cameronsaddress/snapchef-server
   - Default branch: `main`
   - Language: Python/FastAPI
   - Purpose: API server for recipe generation using Grok Vision

### Git Commands for Each Repository

#### For iOS Repository:
```bash
cd /Users/cameronanderson/SnapChef/snapchef/ios
git status
git add .
git commit -m "Your message"
git push origin main
```

#### For Server Repository:
```bash
cd /Users/cameronanderson/snapchef-server/snapchef-server
git status
git add .
git commit -m "Your message"
git push origin main
```

### Best Practices

1. **Always verify your location** before committing:
   - Use `pwd` to check current directory
   - Use `git remote -v` to verify which repository you're in

2. **Keep repositories in sync**:
   - Pull latest changes before starting work
   - Push changes regularly

3. **Clear commit messages**:
   - Prefix with [iOS] or [Server] if helpful
   - Be descriptive about changes

4. **Never mix changes**:
   - Don't copy .git folders between repositories
   - Keep server code in server repo, iOS code in iOS repo

## Server Repository Details

### Key Files:
- `main.py` - Main FastAPI application
- `prompt.py` - AI prompt templates
- `requirements.txt` - Python dependencies
- `dockerfile` - Docker configuration for deployment

### Environment Variables:
- `GROK_API_KEY` - API key for Grok Vision
- `APP_API_KEY` - Authentication key for iOS app (5380e4b60818cf237678fccfd4b8f767d1c94)

### API Endpoint:
- Production: https://snapchef-server.onrender.com
- Main endpoint: POST `/analyze_fridge_image`

## VS Code / Editor Tips

If using VS Code with multiple repositories:
1. Open each repository in its own window, or
2. Use VS Code Workspaces to manage both repos
3. Install GitLens extension for better Git visualization

## Related Documentation

- iOS App: See `/ios/README.md`
- Server: See `/snapchef-server/README.md`
- API Documentation: See `/ios/API_DOCUMENTATION.md`

---

Last Updated: January 31, 2025