### TODO
---

- **BUGFIX: Sometimes track doesn’t change while paused**
  - Don't know what triggers this. maybe inactivity too long.
  - Spotify is open.
  - A track is loaded but not playing, it’s paused.
  - Search a track with castSpot and hit Enter.
  - The track doesn’t change or start playing.
  - **Expected behaviour:**
    - If a different track is selected, it should switch to that track and start playing.
    - If the same track is selected, it should seek back to the start and begin playing.

---

- **BUGFIX: First item is not always focused (FIXED)** 
  - While searching, focus can jump to the item below.
  - Root cause: Focus passes to list element behind mouse cursor, even if mouse cursor is not moving.

---

- **Search bar sometimes does not open**
  - Analyze the root cause (event listeners, state management, focus/blur behavior, conditional rendering, etc.).
  - Note down the reproduction steps and make sure it’s reproducible in a stable way.
  - If needed, review debouncing/throttling and async calls.
  - Implement a permanent fix and add tests for the relevant areas.

---

- **Error handling when access token expires**
  - Identify places where no error is thrown when the access token is dead (expired/invalid).
  - Design a shared error handling/refresh mechanism (e.g. interceptor, middleware, hook).
  - Implement automatic token refresh where appropriate, and a controlled logout flow otherwise.
  - Define the error/warning messages and guidance shown to the user.

---

- **Improve login flow**
  - In the current login flow, there is no visual feedback informing the user after they log in.
  - The Refresh & Access Token logic needs to be revisited.

---

- **Popup window position is not configurable**
  - Window position should be selectable from presets in the settings.
  - Window position should be manually adjustable.
  - It should work correctly with multi‑monitor setups.
  - Window position should persist across sessions.

---

- **Search Tokens** (Concept)
  - Tokenized search to start tracks from specific seconds:
    - `Many Men :10s` – starts from the 10th second.
  - Search by artist:
    - `Many Men :Fifty Cent` – filters to tracks by Fifty Cent.

---

- **Animations**