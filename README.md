# vex_notify

A lightweight notification and UI alert system for RedM.

`vex_notify` provides a centralized notification layer for VEX resources, including standard notifications, alerts, interactive choices, progress displays, and world-space overhead text.

## Features

* Western-themed notification UI
* Toast notifications
* System alerts
* Persistent notifications
* Interactive choice modals
* Progress displays
* World-space overhead text
* Server and client APIs
* NUI-based screen rendering
* `vex_callback` integration for interactive responses
* `vex_core` integration
* No direct VORP dependency

## Dependencies

* `vex_core`
* `vex_callback`

## Installation

Place the resource in your resources directory:

```text
resources/
└── [vex]/
    └── vex_notify/
```

Add it to `server.cfg` after its dependencies:

```cfg
ensure vex_core
ensure vex_callback
ensure vex_notify
```

## Example

```lua
exports['vex_notify']:ShowNotification(
    source,
    'Your horse has been stored.',
    'toast',
    4000
)
```

Client-side:

```lua
exports['vex_notify']:Show(
    'Welcome to town.',
    'toast',
    4000
)
```

## Resource Structure

```text
vex_notify/
├── fxmanifest.lua
├── config.lua
├── shared/
├── server/
├── client/
└── ui/
```

## License

Copyright © VEX. All rights reserved.
