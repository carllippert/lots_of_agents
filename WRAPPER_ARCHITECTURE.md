# Wrapper Architecture: Launch Services Identity Preservation

## Overview

Each Lots of Agents clone is a thin wrapper app that launches the official Grok Bot / Cursor / Claude / ChatGPT binary while preserving its own identity in macOS Launch Services and the Cmd-Tab switcher.

## Structure

```
~/Applications/Grok Bot Personal.app/
├── Contents/
│   ├── Info.plist                      # Unique bundle ID, icon reference
│   ├── MacOS/
│   │   └── TwoCursorsLauncher         # This launcher binary
│   └── Resources/
│       └── AppIcon.icns               # Custom tinted icon
```

## Launch Flow

1. **User opens wrapper** (Finder, Dock, or Launch Services)
   - macOS launches `TwoCursorsLauncher` (the wrapper's `CFBundleExecutable`)
   - Wrapper process starts with bundle ID `app.lotsofagents.clone.grok.personal`

2. **Launcher reads profile configuration**
   - Profile ID from `Info.plist` → `TwoCursorsProfileID`
   - Catalog path → `TwoCursorsCatalog`
   - Recipe ID → `TwoCursorsRecipeID`

3. **Launcher prepares environment**
   - User data directory: `~/Library/Application Support/LotsOfAgents/Profiles/<id>/user-data`
   - Extensions directory: `.../extensions`
   - Optional home overlay for full isolation
   - Removes `ELECTRON_RUN_AS_NODE` from environment

4. **Launcher spawns official binary as child process**
   ```c
   posix_spawn(&pid, 
               "/Applications/Grok Bot.app/Contents/MacOS/Grok Bot",
               NULL, attrs, argv, envp)
   ```
   - Passes `--user-data-dir` and `--extensions-dir` arguments
   - Passes custom environment variables
   - **Wrapper process stays alive** (this is the key)

5. **Wrapper waits for child**
   ```c
   waitpid(pid, &childStatus, 0)
   ```
   - Wrapper remains the "main" process for Launch Services
   - Child runs the actual Electron app
   - When child exits, wrapper exits with same status code

## Why This Works

### Launch Services Identity

macOS Launch Services identifies an app by:
- The **running process** with a `.app` bundle structure
- The `CFBundleIdentifier` in that bundle's `Info.plist`
- The `CFBundleIconFile` resource

Since the wrapper process stays alive and is the one associated with the `.app` bundle, Launch Services shows:
- ✅ Wrapper's bundle ID (e.g., `app.lotsofagents.clone.grok.personal`)
- ✅ Wrapper's icon (`AppIcon.icns`)
- ✅ Wrapper's display name (e.g., "Grok Bot Personal")

### Child Process Behavior

The child process:
- Runs the official Grok Bot binary at `/Applications/Grok Bot.app/Contents/MacOS/Grok Bot`
- Is launched as a **direct executable**, not through the `.app` bundle
- Should not automatically claim the official Grok Bot's Launch Services identity
- Is associated with the parent (wrapper) process

### Cmd-Tab Switcher

The Cmd-Tab app switcher shows:
- Applications with active windows and Launch Services registrations
- The wrapper is the registered app → shows wrapper's icon
- Multiple wrappers appear as separate apps with distinct icons

## Why We Don't Use `execve`

**Old approach (broken):**
```c
execve("/Applications/Grok Bot.app/Contents/MacOS/Grok Bot", argv, envp)
```

Problem:
- `execve` **replaces** the wrapper process entirely
- After replacement, the process IS the official Grok Bot binary
- Launch Services re-identifies it as `com.anysphere.sand` (official bundle ID)
- Cmd-Tab shows the official icon, not the wrapper's icon
- Wrapper's `AppIcon.icns` only appears in Finder, not in app switcher

## Why We Don't Copy the Full `.app` Bundle

Copying the entire Grok Bot.app into each wrapper would:
- ❌ Break Electron helper processes (bundle path mismatches)
- ❌ Break native file pickers (NSOpenPanel expects real bundle)
- ❌ Break file uploads / downloads (hardcoded bundle paths)
- ❌ Break app updates (update mechanism checks bundle path)
- ❌ Break code signing verification (duplicate bundles fail signature checks)
- ❌ Waste disk space (300+ MB per clone)
- ❌ Require re-copying on every Grok Bot update

## Benefits of Current Approach

✅ **One official binary** in `/Applications` — update once, all clones benefit  
✅ **Wrapper identity preserved** — each clone has custom icon in Cmd-Tab  
✅ **No bundle duplication** — thin wrappers are < 1 MB each  
✅ **All Electron features work** — helpers, file pickers, updates, signing  
✅ **Profile isolation works** — `--user-data-dir` separates accounts/chats  
✅ **Multiple clones run simultaneously** — each has its own wrapper process  

## Potential Considerations

### Electron App Self-Identification

Electron apps sometimes try to identify their own bundle location and may attempt to register with Launch Services. If the child process does this, we might see:
- Child process appearing separately in Cmd-Tab (duplicate entry)
- Child claiming official bundle identity despite being launched as direct executable

**Mitigation if needed:**
1. Set process group attributes on `posix_spawn` to associate child with wrapper
2. Use Launch Services APIs to explicitly prevent child from registering
3. Copy only the executable (not full bundle) into wrapper's MacOS folder
4. Use `POSIX_SPAWN_SETSID` to create new session for child

### Process Association

Currently, we spawn the child with default attributes. If needed, we can set:
```c
posix_spawnattr_setpgroup(attrs, 0)  // Create new process group
posix_spawnattr_setflags(attrs, POSIX_SPAWN_SETSID)  // New session
```

This ensures tighter control over how macOS views the parent-child relationship.

### Testing Verification

To verify the fix works:
1. Create a clone in Lots of Agents (e.g., "Grok Bot Personal")
2. Launch the clone
3. Check Cmd-Tab: should show wrapper's custom icon, not official Grok Bot icon
4. Create second clone with different tint (e.g., "Grok Bot Work")
5. Launch both simultaneously
6. Check Cmd-Tab: should show both as separate apps with distinct tinted icons
7. Verify functionality: sign in, chat, extensions all work normally

## Exit Behavior

When the user quits the Electron app (child process):
1. Child process exits with status code (e.g., 0 for normal quit)
2. `waitpid` returns in the wrapper
3. Wrapper reads child's exit status
4. Wrapper exits with same status code

This ensures:
- Wrapper doesn't stay alive after app quits
- Exit status is propagated correctly
- No orphaned processes
- Clean shutdown behavior

## Environment Variable Preservation

All environment variables are passed through to the child:
- User's shell environment
- Custom vars set by the launcher (e.g., `HOME` for overlay mode)
- `ELECTRON_RUN_AS_NODE` is explicitly removed (prevents Electron from running as Node.js)
- `CURSOR_DATA_DIR` set for overlay mode (private `~/.cursor`)

## Arguments Preservation

All command-line arguments are passed through:
- Recipe-specific args: `--user-data-dir`, `--extensions-dir`
- Any args passed to the wrapper (e.g., from URL schemes, file associations)
- Args appear to the child as if it was launched directly

## Future Enhancements

If testing reveals issues with child process identity, potential enhancements:
1. **Process group management**: Use `posix_spawnattr_setpgroup` to control grouping
2. **Session control**: Use `POSIX_SPAWN_SETSID` for tighter isolation
3. **Launch Services APIs**: Use `LSRegisterURL` to explicitly control app registration
4. **Bundle path injection**: Set `CFBundlePath` environment variable for the child
5. **Electron flags**: Pass Electron-specific flags to control its Launch Services behavior

For now, the straightforward `posix_spawn` + `waitpid` approach should work for most cases, as launching a bare executable (not through an `.app` bundle) typically doesn't trigger automatic Launch Services registration.
