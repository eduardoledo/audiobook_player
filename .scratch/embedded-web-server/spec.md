# Embedded Web Server (AirDroid-style Remote Access) Specification

## Problem Statement

Users often want to control playback, manage their audiobook/eBook library, and transfer files between their computer and mobile phone without installing desktop companion software or relying on third-party cloud services.

## Solution

Embed a local HTTP and WebSocket server (`shelf`, `shelf_router`, `shelf_web_socket`) directly into the Flutter mobile application. Serve a rich standalone web SPA (HTML5/CSS/JS) from Flutter assets to allow full remote control, library browsing, and bidirectional file transfers over the local Wi-Fi network.

## User Stories

1. As a user, I want to toggle a web server in my mobile app settings and view a local IP address (e.g., `http://192.168.1.50:8080`), so that I can open it in my computer's web browser.
2. As a user, I want connections from my PC to require explicit approval on my phone (plus PIN or QR camera scan options), so that unauthorized local network devices cannot access my device.
3. As a user, I want to control media playback (play/pause, chapter selection, seek, speed) from my browser in real time via WebSockets.
4. As a user, I want to browse my audiobook and eBook library on my PC and upload/download audio and book files directly to/from my mobile device.

## Implementation Decisions

- **Server Architecture**:
  - `shelf` + `shelf_router` + `shelf_web_socket` running in a Flutter service/isolate or background manager.
  - Serves static Web SPA assets from Flutter assets (`web_remote/` directory).
  - Exposes REST endpoints for `/api/library`, `/api/download`, `/api/upload`, and WebSocket `/ws/playback`.

- **Authentication & Pairing Flow**:
  - Connection trigger displays a prompt/notification on mobile screen: "Approve connection from 192.168.x.x?".
  - Pairing options:
    - Option A: Display 4-digit PIN on mobile app to enter on browser.
    - Option B: Display QR code on PC browser and scan with mobile phone camera.
  - Generates transient session token upon successful pairing.

- **Web Client (SPA)**:
  - Standalone SPA built with modern HTML5, Vanilla CSS (glassmorphism/dark theme), and JS.
  - Features real-time player controller bar, category tree library browser, and drag-and-drop file upload zone.

- **Storage & State Integration**:
  - Interacts directly with `LibraryStorage` for SQLite database reads/writes and `PlayerCubit` for playback events.

## Testing Decisions

- **Testing Seams**:
  - `WebServerService` integration test: Verify HTTP endpoint responses, PIN/token verification, WebSocket broadcasting, and upload/download stream handling.

## Out of Scope

- Cloud relay or internet-facing tunnels (operates strictly within local Wi-Fi subnet).
- User account registration or remote OAuth servers.
