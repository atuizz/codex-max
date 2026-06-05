# Codex Mini

Codex Mini is a local phone-to-Codex bridge for macOS. It lets you open a small web UI from your phone and send text or images into the Codex desktop app running on the same Mac.

This open-source branch is **local-only**:

- no hosted access server
- no hosted or public tunnel integration
- no payment or activation flow
- no bundled private deployment notes
- no collection of chat content outside your Mac

## What it does

- Serves a mobile-friendly web UI on your Mac.
- Lists recent Codex threads from local Codex session files.
- Opens/selects Codex threads through the Codex desktop app.
- Pastes text and image attachments into Codex using macOS automation.
- Shows recent replies/status by reading local Codex logs/session files.
- Works on `localhost` or your LAN IP when your phone and Mac are on the same network.

## Requirements

- macOS
- Node.js 18+
- Codex desktop app installed and signed in
- macOS Accessibility permission for the terminal/App that runs Codex Mini

## Quick start

```bash
npm install
npm start
```

The server prints URLs like:

```text
http://localhost:8787/?token=...
http://<your-lan-ip>:8787/?token=...
```

Open the LAN URL from your phone while the phone and Mac are on the same Wi-Fi.

## LaunchAgent install

To run the local service in the background:

```bash
./scripts/install-local-launchagents.sh
```

Optional environment variables:

```bash
MOBILE_TYPER_TOKEN=your-token PORT=8787 ./scripts/install-local-launchagents.sh
```

Default LaunchAgent label:

```text
codex-mini.local
```

## Build the macOS wrapper app

```bash
./scripts/build-codex-mini-app.sh
```

The default output is:

```text
/Applications/Codex Mini.app
```

The app is a local control panel. It embeds the Node service and writes a local LaunchAgent on first launch.

## Package installer

```bash
./scripts/build-codex-mini-installer.sh
```

This creates a local installer package under `dist/`.

## Security notes

- The phone URL contains an access token. Treat it like a password.
- Codex Mini is intended for trusted local networks.
- Do not expose the local HTTP port directly to the public internet without adding your own security layer.
- Runtime logs, build output, and packaged artifacts are ignored by Git.

## Useful commands

```bash
npm run check
node --check server.js
```
