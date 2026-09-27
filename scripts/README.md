# Utility Scripts

Standalone utilities that can be used system-wide, not just for claudeme.

## cleanup-advisor

**Smart system resource cleanup advisor** - Shows which apps are hogging RAM/CPU with actionable kill commands.

### Use Cases

- **Before benchmarking** - Free up resources for accurate tests
- **Before compiling** - Speed up large builds
- **Before video editing** - Ensure enough RAM for rendering
- **System feels slow** - Diagnose what's eating resources
- **General cleanup** - See what you can safely close

### Installation

**Local use:**
```bash
./scripts/cleanup-advisor
```

**System-wide install:**
```bash
ln -s $(pwd)/scripts/cleanup-advisor ~/.local/bin/
cleanup-advisor  # Now available anywhere!
```

### Usage

```bash
# Show everything
cleanup-advisor

# RAM hogs only
cleanup-advisor --ram

# CPU hogs only
cleanup-advisor --cpu

# Help
cleanup-advisor --help
```

### Example Output

```
Application RAM Totals (multiple processes grouped):

- Visual Studio Code   10 procs  5120MB (5.0GB)
  Kill: code --stop  or  pkill -x 'Code'
  
- Google Chrome        15 procs  3200MB (3.1GB)
  Kill: pkill -x 'Google Chrome'
  
- Slack                 6 procs  1800MB (1.7GB)
  Kill: pkill -x 'Slack'

Potential RAM freed: ~10GB
```

### Features

✅ **Process grouping** - Catches multi-process apps (VSCode, Chrome, Electron apps)  
✅ **Aggregated totals** - See true RAM impact (not just individual processes)  
✅ **Smart filtering** - Hides system processes you shouldn't kill  
✅ **One-line commands** - Ready-to-run kill commands  
✅ **CPU detection** - Find processes hogging CPU  
✅ **Impact estimate** - Shows how much RAM you'd free  

### Real-World Examples

**Before:**
```
$ top
  Code Helper: 500MB
  Code Helper: 480MB
  Code Helper: 520MB
  ... (10 more)
  
  "Hmm, nothing looks too big..."
```

**After:**
```
$ cleanup-advisor

- Visual Studio Code   10 procs  5120MB (5.0GB)  ← Aha!
  Kill: code --stop
```

### Integration with Benchmarking

The benchmark suite automatically suggests running this when bias is detected:

```bash
./benchmark/scripts/run-all.sh

# Output:
# ⚠️ BIAS WARNING: High memory usage
# 
# To free up resources:
#   cleanup-advisor
```

---

## Future Utilities

Ideas for other standalone scripts:
- `port-hunter` - Find what's using a port
- `docker-cleanup` - Clean up Docker resources
- `npm-cache-clear` - Clear all npm/yarn/pnpm caches
- `disk-hogs` - Find large files/directories

*Submit PRs for new utilities!*
