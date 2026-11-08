import type { ReactNode } from "react";

export const metadata = {
  title: "Defne Family Clinic",
};

// Root layout: wraps every page (FR-9.1, FR-9.2).
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: "system-ui, sans-serif", margin: 0 }}>
        {/* Lets keyboard users jump past the navigation */}
        <a href="#main">Skip to content</a>

        <header style={{ padding: "1rem", borderBottom: "1px solid #ccc" }}>
          <strong>Defne Family Clinic</strong>
        </header>

        <main id="main" style={{ padding: "1rem" }}>
          {children}
        </main>

        {/* Screen readers announce messages placed here (aria-live) */}
        <div id="live-region" aria-live="polite" role="status" />
      </body>
    </html>
  );
}
