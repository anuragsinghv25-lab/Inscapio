import type { Metadata, Viewport } from "next";
import { UI } from "@/renderer/ui-strings";
import "@fontsource-variable/bricolage-grotesque/wdth.css";
import "@fontsource-variable/literata/opsz.css";
import "@fontsource-variable/literata/opsz-italic.css";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://inscapio.in"),
  title: { default: "InScapio — Don't just read it. Explore it.", template: "%s — InScapio" },
  description: "InScapio is an interactive knowledge platform where ideas become experiences you can explore.",
  openGraph: { type: "website", siteName: "InScapio" },
  twitter: { card: "summary" },
};

export const viewport: Viewport = {
  themeColor: "#E3E9EA",
  viewportFit: "cover",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#main">{UI.skipToContent}</a>
        {children}
      </body>
    </html>
  );
}
