# Rsync Zero Output Debugging

## Changes Made to PhotoCulling

### 1. Enable Error Checking (`CreateStreamingHandlers.swift`)
- Set `checkForErrorInRsyncOutput = true` to enable exit code checking
- Added `propagateError` handler to log stderr errors when exit code is non-zero
- This allows rsync failures to be visible in the logs

### 2. Add Exit Code and Output Logging (`ExecuteCopyFiles.swift`)
- Log exit code when process terminates
- Log first 10 lines of stdout for debugging
- Log warning when rsync produces no output
- This helps identify silent failures

## Recommended Changes to RsyncProcessStreaming

The RsyncProcessStreaming package captures stderr but only exposes it when the exit code is non-zero. This means if rsync exits with code 0 but writes warnings/info to stderr, they won't be visible.

### Patch Available
A patch file has been created with the following changes to `RsyncProcessStreaming.swift`:

```swift
// In handleTermination method, add after line 359:

// Log termination details for debugging
Logger.process.debugMessage(
    "RsyncProcessStreaming:  Process terminated with exit code \(task.terminationStatus), stdout lines: \(output?.count ?? 0), stderr lines: \(errors.count)"
)

// Log stderr content if present
if !errors.isEmpty {
    Logger.process.debugMessage("RsyncProcessStreaming:  STDERR output:")
    for error in errors {
        Logger.process.debugMessage("  \(error)")
    }
}
```

### To Apply the Patch
1. Navigate to the RsyncProcessStreaming package directory
2. Apply the patch: `git am < rsync-process-streaming-stderr-logging.patch`
3. Or manually add the logging code shown above

## Expected Behavior After Changes

When rsync runs with `--dry-run --verbose`:

### Success Case (Exit Code 0, Output Present)
```
DEBUG: Final arguments: ["--archive", "--verbose", "--dry-run", ...]
RsyncProcessStreaming:  COMMAND - file:///usr/bin/rsync
RsyncProcessStreaming:  Process terminated with exit code 0, stdout lines: 142, stderr lines: 0
DEBUG processTermination: output lines=142, hiddenID=0, exitCode=0
DEBUG processTermination: stdout output (142 lines):
  [0]: Transfer starting: 142 files
  [1]: ./
  [2]: _DSC8780.ARW
  ...
```

### Failure Case (Exit Code != 0)
```
DEBUG: Final arguments: ["--archive", "--verbose", "--dry-run", ...]
RsyncProcessStreaming:  COMMAND - file:///usr/bin/rsync
RsyncProcessStreaming:  Process terminated with exit code 23, stdout lines: 0, stderr lines: 2
RsyncProcessStreaming:  STDERR output:
  rsync: [sender] opendir "/source/path" failed: Permission denied (13)
  rsync error: some files/attrs were not transferred (code 23) at main.c(1330)
ERROR: Rsync process error: rsync exited with code 23.
rsync: [sender] opendir "/source/path" failed: Permission denied (13)
rsync error: some files/attrs were not transferred (code 23) at main.c(1330)
DEBUG processTermination: output lines=0, hiddenID=0, exitCode=23
WARNING: processTermination: NO OUTPUT from rsync!
```

### Silent Failure Case (Exit Code 0, No Output)
```
DEBUG: Final arguments: ["--archive", "--verbose", "--dry-run", ...]
RsyncProcessStreaming:  COMMAND - file:///usr/bin/rsync
RsyncProcessStreaming:  Process terminated with exit code 0, stdout lines: 0, stderr lines: 0
DEBUG processTermination: output lines=0, hiddenID=0, exitCode=0
WARNING: processTermination: NO OUTPUT from rsync!
```

If this case occurs, investigate:
- Is the filter file empty or excluding everything?
- Are the paths correct?
- Is rsync being killed by the sandbox before producing output?

## Testing

1. Run the app with `--dry-run` enabled
2. Check console logs for:
   - Exit code
   - stdout line count
   - stderr content (if any)
   - Warning if no output
3. If exit code is 0 but no output:
   - Check the filter file at `~/Library/Containers/no.blogspot.PhotoCulling/Data/Documents/copyfilelist.txt`
   - Verify paths exist
   - Try running the same rsync command in Terminal
