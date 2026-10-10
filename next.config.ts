import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // v0's hash aliases (#/body, #/climate, #/explore) become real redirects.
  async redirects() {
    return [
      { source: "/body", destination: "/experiences/whose-body-is-it", permanent: true },
      { source: "/climate", destination: "/experiences/climate", permanent: true },
      { source: "/explore", destination: "/#rooms", permanent: true },
    ];
  },
  // Experience content is validated data; there is no dynamic HTML path.
  // A strict Content-Security-Policy is added in a later phase (see docs/architecture/backend-architecture.md).
};

export default config;
