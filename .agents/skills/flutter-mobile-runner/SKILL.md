---
name: flutter-mobile-runner
description: Manage Flutter mobile app lifecycle, including hot reload, hot restart, app updates, and fresh reinstalls in background tasks. Use when the user asks to "reiniciar app", "reinstalar app", "hot reload", "update mobile app", or "iniciar app en el celular".
---

# Flutter Mobile Runner Skill

Automate and manage the execution lifecycle of the Flutter mobile app on connected Android/iOS devices or emulators, adhering strictly to the user requirement of executing long-running compilation or installation tasks in background processes to keep the development workspace unblocked.

## Core Rules

1. **Always Background Execution**: Every time a build, run, update, or reinstall command is initiated, execute it asynchronously in the background (`run_command` with `IsDaemon: true` or background task) so that the interactive development flow remains uninterrupted.
2. **Device Discovery**: Before running or reinstalling, if a target device ID isn't known or previously selected, check available devices using `flutter devices`.
3. **Single Active Instance Management**: When performing a reinstall, update, or restart, kill any existing `flutter run` background task first via `manage_task` (Action: `kill`) to avoid device lock issues or parallel conflicting builds.

## Action Workflows

### 1. Hot Reload / Hot Restart
- If `flutter run` is actively running in an interactive terminal or daemon task:
  - Hot Reload: Send `r` stdin input using `manage_task` (Action: `send_input`, Input: `"r\n"`).
  - Hot Restart: Send `R` stdin input using `manage_task` (Action: `send_input`, Input: `"R\n"`).
- If no active interactive task is attached, fallback to performing an App Update.

### 2. Update Mobile App (Fast Run / Incremental Build)
- Run `flutter run -d <device_id>` in the background:
  - Tool: `run_command`
  - Arguments: `CommandLine: "flutter run -d <device_id>"`, `IsDaemon: true`, `WaitMsBeforeAsync: 2000`
- Notify the user with the background task ID and keep the conversation open for further instructions.

### 3. Reinstall Mobile App (Clean Install)
- Kill any existing `flutter run` task using `manage_task`.
- Run clean installation with `--uninstall-first` in the background:
  - Tool: `run_command`
  - Arguments: `CommandLine: "flutter run -d <device_id> --uninstall-first"`, `IsDaemon: true`, `WaitMsBeforeAsync: 2000`
- Notify the user with the background task ID.
