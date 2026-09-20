# Issue 01: `WebServerService` Engine & Local HTTP/WebSocket Endpoints

## Status

- [ ] Spec: [.scratch/embedded-web-server/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/embedded-web-server/spec.md)

## Goal

Implement `WebServerService` using Dart `shelf` and `shelf_web_socket` to run a local HTTP/WS server on the mobile device, manage network bindings, and expose REST/WS endpoints for player control, library access, and file transfers.

## Tasks

- [ ] Add `shelf`, `shelf_router`, `shelf_static`, and `shelf_web_socket` dependencies to `pubspec.yaml`.
- [ ] Create `WebServerService` with start/stop lifecycle methods and IP/port discovery.
- [ ] Implement REST endpoints for `/api/library`, `/api/download`, and `/api/upload`.
- [ ] Implement WebSocket endpoint `/ws/playback` broadcasting `PlayerState` changes in real time.
- [ ] Add unit and service integration tests verifying local HTTP/WS requests and upload handling.
