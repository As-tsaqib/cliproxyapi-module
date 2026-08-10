# CLIProxyAPI Magisk

ARM64 Android Magisk/KernelSU/Next SU module builder for
[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI).

Author: As-tsaqib

This repository does not fork CLIProxyAPI source code. GitHub Actions checks
out an official upstream release, builds an Android-native ARM64 binary,
overlays the root-module packaging, bundles the management dashboard, and
publishes a traceable release archive.

## Requirements

- ARM64 (`arm64-v8a`) device.
- Android 7.0/API 24 or newer.
- A current Magisk, KernelSU, or Next SU manager.
- Installation through the root manager; custom-recovery installation is not
  supported or tested.

## Installation

1. Download `cliproxyapi-magisk.zip` and `checksums.txt` from the
   [latest release](https://github.com/As-tsaqib/CLIProxyAPI-Magisk/releases/latest).
2. Verify the download with `sha256sum -c checksums.txt` when that tool is
   available.
3. Install the ZIP from the module page in Magisk, KernelSU, or Next SU.
4. Reboot, then open the module action to inspect its health report.
5. Log in with the initial dashboard password `admin123`, immediately rotate it
   with `cliproxyapi dashboard-password`, then configure provider credentials.

## Security Defaults

The default listener is `0.0.0.0:8317` and remote management is allowed so
trusted LAN and hotspot clients can connect. A fresh install generates a unique
256-bit client API key and initially enables the dashboard with password
`admin123`. Change that password immediately after installation. Never expose
port 8317 directly to the internet or an untrusted network.

## Secure LAN Access

The generated config is equivalent to the following. The client API key is
unique per installation; the initial management password must be rotated:

```yaml
host: "0.0.0.0"
port: 8317

api-keys:
  - "replace-with-a-long-random-client-key"

remote-management:
  allow-remote: true
  secret-key: "admin123"
```

Restart the service after editing. Remote management uses the management key,
while proxy requests use the separate client API key. Access over an untrusted
network should be protected by a firewall or an authenticated TLS tunnel.

## Dashboard

The bundled `management.html` supports an offline first run and the root
manager WebUI redirects to it. CLIProxyAPI requires
`remote-management.secret-key` even for local management requests, so set that
value before expecting dashboard controls to work.

When Termux is installed, configure or rotate that key with one interactive
command. Input is hidden, confirmed twice, written without exposing it in the
process arguments, and the service is restarted with a health check:

```sh
cliproxyapi dashboard-password
```

Then open `http://127.0.0.1:8317/management.html` on the Android device, or use
the Android device's LAN/hotspot IP from another trusted device, and enter the
management key. When it creates the `remote-management` section, the helper
enables remote management by default.

## Runtime Behavior

- Starts CLIProxyAPI from the root manager's late-start service stage.
- Restarts a crashed process with bounded backoff to avoid a tight crash loop.
- Rejects stale PID files instead of signaling unrelated Android processes.
- Preserves configuration and provider authentication across module upgrades.
- Stores state outside the replaceable module directory in
  `/data/adb/cliproxyapi`.
- Serves the API on all interfaces at port `8317` by default.

Disable autostart and stop the running service:

```sh
touch /data/adb/cliproxyapi/disable
```

Stop it for the current boot only:

```sh
touch /data/adb/cliproxyapi/stop
```

Start it again during the same boot:

```sh
rm -f /data/adb/cliproxyapi/disable /data/adb/cliproxyapi/stop
sh /data/adb/modules/cliproxyapi/service.sh
```

## Paths

- Config: `/data/adb/cliproxyapi/config.yaml`
- Provider auth files: `/data/adb/cliproxyapi/auths`
- App stdout/stderr: `/data/adb/cliproxyapi/cliproxyapi.log`
- Rotating application logs: `/data/adb/cliproxyapi/logs`
- Watchdog log: `/data/adb/cliproxyapi/watchdog.log`
- Dashboard: `/data/adb/cliproxyapi/static/management.html`

## Termux CLI Wrapper

When Termux already exists, the installer adds a `cliproxyapi` wrapper that
forwards CLIProxyAPI arguments through `su` and supplies the module config by
default. An unrelated existing executable is not overwritten.

```sh
cliproxyapi -h
cliproxyapi -codex-login -no-browser
cliproxyapi -codex-device-login
cliproxyapi -claude-login -no-browser
```

## Uninstall and Credential Removal

Normal uninstall stops the service and removes the module-owned Termux wrapper,
but intentionally preserves `/data/adb/cliproxyapi` for later reinstall. That
directory contains configuration and provider tokens; permanently erase it
only when those credentials are no longer needed:

```sh
su -c 'rm -rf /data/adb/cliproxyapi'
```

## Release Flow

- A scheduled workflow checks the latest upstream CLIProxyAPI release at
  00:00, 06:00, 12:00, and 18:00 UTC every day.
- An existing published release and tag are never deleted or overwritten.
- Manual dispatch can build the latest release or a specific semantic tag.
- `versionCode` reserves its final two digits for immutable `r1`–`r99`
  packaging revisions, so subsequent upstream versions remain newer.
- Release notes record the CLIProxyAPI commit, model catalog commit, dashboard
  release, and dashboard digest used by the build.
- The release contains the module ZIP, SHA-256 checksum, and provenance; the
  ZIP itself includes the project license and third-party notices.

## Manual Build in Actions

Open **Actions → Release Magisk Module → Run workflow** and optionally provide
an upstream tag such as `v7.2.79`. If the upstream version was already
published, set `force=true` to create the first free immutable revision tag
from `v7.2.79-r1` through `v7.2.79-r99` rather than replacing the original.

## Local Build

Put build inputs here:

```text
packaging/magisk/bin/cli-proxy-api
packaging/magisk/static/management.html
```

Then run:

```sh
VERSION=v7.2.79 VERSION_CODE=700207900 ./packaging/magisk/build-module.sh
```

The resulting archive is `dist/magisk/cliproxyapi-magisk.zip`.

## Validation

Pull requests and pushes validate shell syntax, workflow syntax, module
metadata, executable permissions, archive contents, and Android ELF properties.
Device-level verification is still recommended when changing boot, SELinux, or
root-manager integration behavior.

## License

Packaging code is available under the [MIT License](LICENSE). Upstream notices
shipped with release archives are recorded in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
