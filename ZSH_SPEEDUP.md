# ZSH Startup Time Optimization

**Status**: In Progress
**Goal**: Reduce zsh startup time from ~800ms to ~150ms (3-5x speedup)
**Started**: 2026-01-03

---

## Executive Summary

Optimizing zsh startup by addressing major bottlenecks:
- **kubectl completion**: 300-800ms (lazy-load)
- **NVM loading**: 100-400ms (lazy-load)
- **Duplicate code**: 20-50ms (remove)
- **Tool initialization**: 80-200ms (defer atuin/zoxide/sesh)

---

## Progress Tracking

- [x] **Step 1**: Measure baseline
- [ ] **Step 2**: Create profiling module
- [ ] **Step 3**: Remove duplicate code
- [ ] **Step 4**: Lazy-load kubectl completions
- [ ] **Step 5**: Lazy-load NVM
- [ ] **Step 6**: Defer tool initializations
- [ ] **Step 7**: Measure results

---

## Baseline Measurements

**Date**: 2026-01-03
**Average startup time**: **1.38 seconds** (1380ms)

Results from 5 runs:
```
real 1.43
real 1.37
real 1.38
real 1.39
real 1.36
```

**This is significantly slower than expected!** The optimizations should have major impact.

---

## Implementation Details

### Step 1: Profiling Module

**File**: `home/modules/zsh-profiling.nix`

Created module to enable/disable zsh profiling using `zprof`.

**Usage**:
```nix
programs.zsh-profiling.enable = true;  # Enable profiling
```

### Step 2: Remove Duplicate Code

**File**: `home/bcotton.nix`

**Removed** lines 344-353 from `initContent`:
- Duplicate NVM loading (lines 344-346)
- Duplicate podman check (lines 348-351)
- Duplicate sensitive env (line 353)

These were already present in `envExtra` section.

**Impact**: 20-50ms savings

### Step 3: Lazy-Load kubectl

**File**: `home/modules/kubectl-lazy.nix`

Created module that wraps `kubectl` and `k` commands to load completions on first use.

**Changes to bcotton.nix**:
- Removed line 355: `source <(kubectl completion zsh)`
- Import and enable `kubectl-lazy` module

**Impact**: 300-800ms savings (BIGGEST WIN!)

**Trade-off**: First kubectl/k command has one-time delay

### Step 4: Lazy-Load NVM

**File**: `home/modules/nvm-lazy.nix`

Created module that wraps `nvm`, `node`, and `npm` commands to load NVM on first use.

**Changes to bcotton.nix**:
- Removed lines 266-268: NVM loading from `envExtra`
- Import and enable `nvm-lazy` module

**Impact**: 100-400ms savings

**Trade-off**: First nvm/node/npm command has one-time delay

### Step 5: Defer Tool Initialization

**Changes to bcotton.nix**:
- Added `zsh-defer` to packages
- Modified `initContent` to defer atuin, zoxide, and sesh initialization

Tools now initialize in background after prompt displays.

**Impact**:
- Atuin: 50-100ms savings
- Zoxide: 20-50ms savings
- Sesh: 10-20ms savings

**Trade-off**: Tools may not be ready if used immediately after shell start

---

## Final Results

**Date**: TBD
**Average startup time**: TBD
**Improvement**: TBD

### Detailed Breakdown (zprof output)

TBD

---

## Testing Checklist

Verify all functionality after optimizations:

- [ ] `kubectl version` works
- [ ] `k version` (alias) works
- [ ] `kubectl get pods` shows completions (after first use)
- [ ] `nvm --version` works
- [ ] `node --version` works
- [ ] `npm --version` works
- [ ] Ctrl-R opens atuin history search
- [ ] `z ~` works (zoxide navigation)
- [ ] Alt-s opens sesh session picker
- [ ] `cd` command works
- [ ] Custom functions work: `grf`, `kg`, `gwt2`, `rgf`
- [ ] Git prompt shows correct information
- [ ] Kubernetes context shows in prompt

---

## Key Files Modified

1. `home/bcotton.nix` - Main configuration
2. `home/modules/zsh-profiling.nix` - Profiling module (new)
3. `home/modules/kubectl-lazy.nix` - kubectl lazy-loading (new)
4. `home/modules/nvm-lazy.nix` - NVM lazy-loading (new)

---

## Rollback

Each optimization is a separate git commit:
```bash
git log --oneline  # Find commit to revert
git revert <commit-hash>
just build && just switch
```

---

## Trade-offs Summary

1. **First-use delay**: kubectl/k and nvm/node/npm have one-time delay on first use per shell
2. **Deferred tools**: atuin/zoxide/sesh initialize in background after prompt
3. **Increased modularity**: More files, but easier to toggle optimizations

---

## Future Enhancements

- [ ] Compile zsh configs with `zcompile`
- [ ] Async prompt rendering for git-taculous theme
- [ ] Cache kubectl completions to file
- [ ] Profile individual oh-my-zsh plugins
- [ ] Consolidate into single `zsh-lazy-load.nix` module

---

## Notes

- **git-taculous theme**: Runs git commands in `precmd` hook (affects prompt rendering, not startup)
- **Custom plugins**: Lightweight, no significant overhead
- **Atuin daemon**: Already running as systemd service (on Linux)
- **Sensitive env**: `~/.config/sensitive/.zshenv` - unknown contents, potential bottleneck
