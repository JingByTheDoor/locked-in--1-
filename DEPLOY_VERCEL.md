# Deploying to Vercel

This project is configured for easy deployment to Vercel. Because this is a Godot 4 game, it requires special security headers (COOP/COEP) to run in the browser, which have been added to the `vercel.json` file.

## Steps to Deploy

1.  **Export the game from Godot:**
    *   Open your project in Godot.
    *   Go to **Project > Export**.
    *   Add a **Web** preset.
    *   Set the **Export Path** to `public/index.html`.
    *   Ensure **Export With Debug** is off for production.
    *   Click **Export Project**.

2.  **Vercel Configuration:**
    *   Push your code to GitHub (including the `public` folder and `vercel.json`).
    *   Connect your repository to Vercel.
    *   Vercel should automatically detect the settings.
    *   **Framework Preset:** Other (or let it auto-detect).
    *   **Output Directory:** `public`

3.  **Manual Upload (Optional):**
    *   If you have the Vercel CLI, run `vercel` in the project root.

## Files created:
- `vercel.json`: Configures the required `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers.
- `package.json`: Helps Vercel recognize the project structure.
