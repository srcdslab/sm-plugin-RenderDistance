# Copilot Instructions for sm-plugin-RenderDistance

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod called **RenderDistance**. The plugin allows players on Source engine game servers (CS:GO, CS:Source) to control the render distance of entities, effectively reducing visual clutter and potentially improving performance by hiding distant objects.

### Key Features
- Per-player render distance control (800-4000 units)
- Toggle fire rendering on/off
- Bind mode for temporary activation
- Client preferences stored via cookies
- Multi-language support via translation files
- Entity transmission hooks for performance optimization

## Technical Environment

### Core Technologies
- **Language**: SourcePawn
- **Platform**: SourceMod 1.11.0+ (compatible with 1.12+)
- **Build System**: SourceKnight (NOT traditional spcomp)
- **Games**: Counter-Strike: Global Offensive, Counter-Strike: Source
- **Dependencies**: MultiColors plugin for colored chat messages

### Build System - SourceKnight
This project uses **SourceKnight** instead of traditional SourceMod compilation:
- Configuration file: `sourceknight.yaml`
- Build command: `sourceknight build` (handled by CI)
- Dependencies are automatically downloaded and managed
- Output goes to `/addons/sourcemod/plugins`

**Important**: Do NOT use `spcomp` directly. The build system handles compilation through GitHub Actions.

## File Structure

```
addons/sourcemod/
├── scripting/
│   └── RenderDistance.sp          # Main plugin source code
├── gamedata/
│   └── render_distance.games.txt  # Game signatures for SDK calls  
└── translations/
    └── renderdistance.phrases.txt # Translation phrases

.github/
├── workflows/
│   └── ci.yml                     # CI/CD pipeline
└── copilot-instructions.md        # This file

sourceknight.yaml                   # Build configuration
```

## Code Style & Standards (Project-Specific)

### SourcePawn Standards Applied
- ✅ `#pragma semicolon 1` and `#pragma newdecls required`
- ✅ 4-space indentation (tabs)
- ✅ camelCase for local variables, PascalCase for functions
- ✅ Global variables prefixed with lowercase type indicators (e.g., `bEnabled`, `iDistance`, `hCookie`)
- ✅ Proper memory management with `delete` (no null checks needed)

### Project-Specific Patterns
1. **Client Data Arrays**: Use `[MAXPLAYERS + 1]` sizing pattern:
   ```sourcepawn
   bool bEnabled[MAXPLAYERS + 1];
   int iDistance[MAXPLAYERS + 1]; 
   ```

2. **Cookie Handling**: Standard pattern for client preferences:
   ```sourcepawn
   Handle hCookieExample;
   // In OnPluginStart:
   hCookieExample = RegClientCookie("name", "desc", CookieAccess_Public);
   ```

3. **Menu Systems**: Consistent menu handling with proper cleanup:
   ```sourcepawn
   Menu menu = new Menu(MenuHandler);
   // ... populate menu
   menu.Display(client, MENU_TIME_FOREVER);
   // MenuAction_End: menu.Close();
   ```

4. **Translation Integration**: Use MultiColors with translation keys:
   ```sourcepawn
   CPrintToChat(client, "[%T] %s", "Render Distance", client, message);
   ```

## Key Components & Architecture

### 1. Entity Management
- **Entity List**: Hardcoded array of entity classnames to monitor
- **Hook System**: Uses `SDKHook(entity, SDKHook_SetTransmit, DoTransmit)`
- **Sphere Detection**: Custom SDK call to `CGlobalEntityList::FindEntityInSphere()`

### 2. Client Preferences  
- **Cookies**: Persistent storage for user settings
- **Real-time Control**: Immediate effect when settings change
- **Bind Mode**: Temporary activation with key binds

### 3. Game Compatibility
- **GameData**: Signatures for CS:GO and CS:Source in `render_distance.games.txt`
- **Engine Differences**: Handles different memory layouts between games

## Common Development Tasks

### Adding New Entity Types
1. Add classname to `entityList[]` array in main source file
2. Consider performance impact (frequent transmission checks)
3. Test with both CS:GO and CS:Source

### Modifying Distance Options
1. Update distance menu in `ShowDistanceMenu()` function
2. Ensure minimum distance validation (≥800 units)
3. Update cookie handling if needed

### Adding New Client Settings
1. Declare global variable array `[MAXPLAYERS + 1]`
2. Register cookie in `OnPluginStart()`
3. Load cookie value in `OnClientCookiesCached()`
4. Add menu option in `ShowRenderMenu()`
5. Handle in `MenuHandlerRender()`

### Translation Updates
1. Edit `addons/sourcemod/translations/renderdistance.phrases.txt`
2. Follow existing format with language codes
3. Test with `%T` formatting in source code

## Build & Deployment

### Local Development
- No local compilation needed - use GitHub Actions
- Make changes and push to see build results
- CI automatically builds on all pushes/PRs

### Testing Changes
1. **Syntax Check**: CI will catch compilation errors
2. **Manual Testing**: Deploy to test server with SourceMod
3. **Gamedata Validation**: Test on both CS:GO and CS:Source if gamedata changes

### Release Process
- Automatic releases on `master`/`main` branch
- Tagged releases create versioned artifacts
- Package includes compiled plugin + gamedata + translations

## Troubleshooting Common Issues

### Build Failures
- Check SourceKnight configuration in `sourceknight.yaml`
- Verify dependency versions (SourceMod, MultiColors)
- Review CI logs in GitHub Actions

### Gamedata Issues
- Signatures may break with game updates
- Check `render_distance.games.txt` for correct offsets
- Test on both CS:GO and CS:Source

### Performance Problems
- Monitor entity count and transmission frequency
- Consider adding entity type filters
- Review sphere detection radius usage

## Integration Points

### Dependencies
- **SourceMod**: Core platform (1.11.0+)
- **MultiColors**: For colored chat messages (`#include <multicolors>`)
- **clientprefs**: For persistent user settings
- **sdkhooks**: For entity transmission hooks

### External Interactions
- **GameData**: Engine-specific memory signatures
- **Translation System**: Multi-language support
- **Menu System**: SourceMod's built-in menu framework

## Security Considerations

- No SQL injection risks (no database usage)
- Client input validation for distance values
- Proper bounds checking for arrays
- Safe entity reference handling with `EntIndexToEntRef()`

## Performance Notes

- Entity transmission hooks are performance-critical
- Minimize work in `DoTransmit()` callback
- Cache frequently accessed values
- Consider entity count impact on sphere detection

---

**Remember**: This is a specialized SourcePawn plugin with game-specific optimizations. Always test changes on actual game servers and consider the performance impact of entity transmission modifications.