# v2.2.0-beta.7

- Extend runtime repair mounts to already-running zygote child namespaces.
- Remove stale runtime Conscrypt mirror directories after successful staging.
- Add KernelSU/Hybrid Mount visibility fields to the doctor command.
- Align fork update metadata with the current beta module version.
- Skip stable update metadata rewrites for prerelease tag builds.
- Use Hybrid Mount's current positional API with fallback to legacy flags.
- Speed up trust-store staging by bulk-copying CA files and pruning AdGuard certs by hash.
- Make staging idempotent after the trust stores are already mounted from the module.
- Report trust-store preparation failures separately from missing AdGuard certificates.
- Recover from stale/deleted bind mounts by lazily unmounting and retrying namespace binds.

# v2.1.1

_Commit titles and messages for `v2.1..v2.1.1`._

## Fix update json (#55)


- Commit: `73d738c`
- Author: Sergey Fionov
- Date: 2024-01-23

## Create LICENSE.md (#58)

Fixes #57
- Commit: `19ecd61`
- Author: Sergey Fionov
- Date: 2024-04-10

## Fix: Ensure proper timing by waiting for zygote64 process to start

Added a loop to wait for the zygote64 process before executing critical certificate operations. This prevents race conditions during module initialization and ensures compatibility with the system boot sequence.
- Commit: `125d287`
- Author: Lars Martens
- Date: 2024-12-06

## Fix: Improve handling of Android 14/15 APEX CA directory with better cleanup and safety checks

Updated the script to enhance temporary directory management for handling Android 14 APEX CA storage:
- Changed `rm -f` to `rm -rf` to ensure proper cleanup of temporary directories.
- Replaced hardcoded paths with a reusable `TEMP_DIR` variable for clarity and maintainability.
- Added a loop to ensure safe unmounting of the temporary directory, preventing "Device or resource busy" errors.
- Commit: `99a923e`
- Author: Lars Martens
- Date: 2024-12-06

## ci: add daily upstream sync workflow


- Commit: `f94803c`
- Author: Lars Martens
- Date: 2026-03-19

## fix(ci): preserve fork workflows during sync


- Commit: `981a43a`
- Author: Lars Martens
- Date: 2026-03-19

## fix(ci): update artifact action version


- Commit: `0b6631a`
- Author: Lars Martens
- Date: 2026-03-19

## fix(ci): harden upstream sync conflict handling


- Commit: `1b225b2`
- Author: Lars Martens
- Date: 2026-03-25

## fix(update): point module feed to fork releases


- Commit: `769d64b`
- Author: Lars Martens
- Date: 2026-03-25
