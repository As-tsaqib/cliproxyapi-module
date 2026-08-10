# CLIProxyAPI

[![Release](https://img.shields.io/github/v/release/As-tsaqib/CLIProxyAPI-Magisk?style=flat-square&color=38bdf8)](https://github.com/As-tsaqib/CLIProxyAPI-Magisk/releases/latest)
[![License](https://img.shields.io/github/license/As-tsaqib/CLIProxyAPI-Magisk?style=flat-square&color=f59e0b)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%207.0%2B%20(ARM64)-emerald?style=flat-square)](#requirements)

High-Performance ARM64 Android boot service & root module for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI).

**Author:** As-tsaqib

---

![CLIProxyAPI Banner](banner.png)

## ✨ Features

- **Native ARM64 Daemon:** Compiled specifically for Android 7.0+ (API 24+) ARM64 devices.
- **Boot Autostart & Watchdog:** Automatic background startup with guarded crash-recovery.
- **WebUI Management:** Embedded Management Dashboard (`http://127.0.0.1:8317/management.html`).
- **Termux Integration:** Auto-installed `cliproxyapi` CLI wrapper for direct Termux control.
- **Automated Upstream Sync:** GitHub Actions automatically checks and builds official releases every 12 hours.

---

## ⚡ Quick Start

1. Download **`cliproxyapi-magisk.zip`** from the [Latest Release](https://github.com/As-tsaqib/CLIProxyAPI-Magisk/releases/latest).
2. Install the ZIP inside **KernelSU Next**, **APatch**, or **Magisk Manager**.
3. Reboot device.
4. Open WebUI at `http://127.0.0.1:8317/management.html` (Initial password: `admin123`).

---

## 🔑 Security & Password Rotation

To change the default dashboard password (`admin123`) from Termux:

```sh
cliproxyapi dashboard-password
```

---

## 💻 Termux CLI Commands

```sh
# View help & available flags
cliproxyapi -h

# Authenticate providers
cliproxyapi -antigravity-login -no-browser
cliproxyapi -claude-login -no-browser
cliproxyapi -codex-device-login
```

---

## 📁 System Paths & Control

| Component | Path / Command |
| :--- | :--- |
| **Config File** | `/data/adb/cliproxyapi/config.yaml` |
| **Provider Auths** | `/data/adb/cliproxyapi/auths/` |
| **App Logs** | `/data/adb/cliproxyapi/cliproxyapi.log` |
| **Disable Service** | `touch /data/adb/cliproxyapi/disable` |
| **Restart Service** | `sh /data/adb/modules/cliproxyapi/service.sh` |

---

## 🛠️ Local Build

```sh
VERSION=v7.2.127 VERSION_CODE=700212700 ./packaging/magisk/build-module.sh
```

---

## 📄 License

Distributed under the [MIT License](LICENSE). Third-party software notices are available in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
