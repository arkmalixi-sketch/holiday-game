# 🎁 Holiday Streamer Game Board

**An interactive, automated board game for TikTok/Twitch Live Streamers.**

This is a browser-based game board designed to run as an **OBS Browser Source** or on an iPad/Tablet during a live stream. It gamifies viewer donations (Gifts) by moving player pawns across a board filled with traps, prizes, and power-ups.

---

## 🎮 Features

* **⚡️ Automated Gameplay:** Connects via WebSocket (Streamer.bot) to automatically move players when they send gifts.
* **🏆 Live Leaderboard:** Real-time ranking updates at the bottom of the screen.
* **💾 Auto-Save:** Never lose progress. If the browser closes, the game remembers player positions and settings.
* **🎨 Dual Themes:** Switch between a festive **Holiday Theme** ❄️ and a sleek **Dark Mode** 🌑.
* **🛠 Customizable:** Change the Board Title, Instructions, and toggle specific Power-Ups on/off.
* **🎲 Power-Ups:**
    * **⛔️ Hidden Trap:** Teleports around the board. If a player steps on it, they get knocked back 1 space.
    * **💎 Live Points:** A teleporting treasure.
    * **🎰 Spin The Wheel:** Grants a special reward chance.
    * **👑 Golden Pawn:** Turns the player's piece Gold.
    * **👕 T-Shirt:** One-time claimable prize.
    * **🎁 Custom Tile:** Create your own custom popup message and place it on any tile.

---

## 🚀 Quick Start (Manual Play)

You don't need to be a coder to use this.

1.  **Open the Game:** [Click here to view your hosted site] (Replace this text with your GitHub Pages link, e.g., https://yourname.github.io/holiday-game/)
2.  **Add Players:** Type a name (Max 4 letters) and click `+`.
3.  **Move Players:** Click the `➡️` arrow next to a player's name to move them forward.
4.  **Reset:** Click "Reset Board" to clear everything and start a new round.

---

## 📡 Automated Setup (Streamer.bot)

To make the game move **automatically** when viewers send gifts on TikTok:

### 1. Requirements
* **PC** running Windows (for the bridge software).
* **[Streamer.bot](https://streamer.bot/)** (Free).

### 2. Configure Streamer.bot
1.  Open **Streamer.bot**.
2.  Go to **Platforms** -> **TikTok** and login to your account.
3.  Go to the **Servers/Clients** tab -> **WebSocket Server**.
4.  Settings:
    * **Address:** `127.0.0.1`
    * **Port:** `8080`
    * **Auto Start:** Checked
5.  Click **Start Server**.

### 3. Connect the Game
1.  Open the Game Board website on the **same computer** running Streamer.bot.
2.  The status indicator under the title should turn from **🔴 Disconnected** to **🟢 Connected**.
3.  **Test it:** Send a test Gift event in Streamer.bot, or wait for a real gift!

---

## ⚙️ Customization

Click the **Settings** button (Gear Icon) to access the Admin Panel:

* **Visuals:** Change the Title and Subtitle text.
* **Toggles:** Turn specific Power-Ups ON or OFF.
* **Randomize:** Click "Randomize Board" to instantly shuffle all traps and prizes to new locations.
* **Simulation:** Use the "🧪 Simulate Gift" button to test animations without being live.

---

## 📱 Use on iPad/Tablet

1.  Open the website link in Safari/Chrome on your iPad.
2.  Control the game manually using the touchscreen.
3.  Use a capture card or screen mirroring to show the iPad on your stream layout.

---

## 🔒 Privacy & Data

* **Local Storage:** All game data is stored locally in your browser. No data is sent to external servers.
* **Open Source:** You are free to modify the code for your own channel branding.

---

##  iOS Native Version (Mac/iPad Only)

If you prefer a native app experience and have a Mac with Xcode:

1.  **Get the Code:** Go to the `/ios` folder in this repository and open `ContentView.swift`.
2.  **Open Xcode:** Create a new "iOS App" project.
3.  **Paste:** Replace the default code in `ContentView.swift` with the code from this repo.
4.  **Run:** Connect your iPad and hit Play!

---

*Built for the streaming community.*

Like it? Tip or Buy me a coffee: https://ko-fi.com/arkayy18
