# ZattooWatcher

**ZattooWatcher** ist eine Anwendung für Roku OS (z. B. für Roku TV-Sticks und Roku Smart-TVs), mit der du Zattoo-Streams komfortabel auf deinem Gerät nutzen kannst.

---

## 📑 Inhalt

- [Über das Projekt](#-über-das-projekt)
- [Features](#-features)
- [Voraussetzungen](#-voraussetzungen)
- [Installation (Sideloading)](#-installation-sideloading)
- [Entwicklung](#-entwicklung)
- [Lizenz](#-lizenz)

---

## ℹ️ Über das Projekt

ZattooWatcher wurde entwickelt, um eine einfache und performante Möglichkeit zu bieten, Zattoo auf Roku-Geräten zu nutzen. Die App basiert auf BrightScript / SceneGraph für Roku OS.

---

## ✨ Features (in Progress)

- 📺 **Live-TV:** Streamen von Live-Fernsehkanälen
- 📑 **EPG / Programmübersicht:** Übersicht über das aktuelle und kommende Programm
- ⚡ **Schnelle Navigation:** Für die Bedienung per Roku-Fernbedienung optimiert

---

## 📋 Voraussetzungen

Bevor du die App installierst, stelle sicher, dass du Folgendes hast:
1. Ein **Roku-Gerät** (Streaming Stick, Express, Streambar oder Roku TV).
2. Einen **Zattoo-Account** (Free, Premium oder Ultimate).
3. Dein Roku-Gerät und dein Computer müssen sich im **selben WLAN-Netzwerk** befinden.

---

## 🚀 Installation (Sideloading)

Da sich die App aktuell in der Entwicklung befindet, erfolgt die Installation über den Roku Developer Mode:

### 1. Developer Mode auf dem Roku-Gerät aktivieren
Drücke auf deiner Roku-Fernbedienung folgende Tastenkombination:
- **Home** (5x)
- **Vorwärts / Fast Forward** (3x)
- **Rückwärts / Rewind** (2x)

Notiere dir die **IP-Adresse** deines Roku-Geräts sowie das vorgegebene Passwort (oder lege ein neues fest). Das Gerät startet anschließend neu.

### 2. App-Paket erstellen
1. Klone das Repository:
   ```bash
   git clone https://github.com/dein-username/ZattooWatcher.git
   cd ZattooWatcher
   ```
2. Erstelle eine `.zip`-Datei aus dem Inhalt des Projektverzeichnisses (enthält `manifest`, `components/`, `source/` etc.).

### 3. App auf das Roku-Gerät hochladen
1. Öffne einen Webbrowser auf deinem PC/Mac und gib die IP-Adresse deines Roku-Geräts ein (z. B. `http://192.168.1.50`).
2. Melde dich mit dem Benutzernamen `gdmk` und dem zuvor festgelegten Passwort an.
3. Klicke auf **Upload** und wähle die erstellte `.zip`-Datei aus.
4. Klicke auf **Install**. Die App startet automatisch auf deinem TV!

---

## 🛠️ Entwicklung

- **Programmiersprache:** BrightScript
- **UI-Framework:** Roku SceneGraph (RSG)

---

## 📄 Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).

---

> **Hinweis:** *ZattooWatcher steht in keiner offiziellen Verbindung zu Zattoo. Alle Produktnamen und Marken sind Eigentum der jeweiligen Inhaber.*