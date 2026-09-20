# Issue 02: Mobile Pairing, Authentication & Approval Flow

## Status

- [ ] Spec: [.scratch/embedded-web-server/spec.md](file:///home/eduardo/Development/audiobook_player/.scratch/embedded-web-server/spec.md)

## Goal

Implement connection approval and authentication mechanisms in the mobile app, including PIN generation, mobile approval dialog, QR code scanning support, and session token validation.

## Tasks

- [ ] Implement mobile on-screen approval dialog when a new PC IP requests access.
- [ ] Implement 4-digit PIN generation on mobile and PIN verification endpoint for browser.
- [ ] Add mobile QR code scanner view (using `mobile_scanner` or camera integration) to scan PC pairing QR codes.
- [ ] Implement session token generation and authentication middleware for protected `shelf` endpoints.
- [ ] Add unit tests for PIN/token verification and pairing flows.
