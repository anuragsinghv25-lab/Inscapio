import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // Experience content is validated data; there is no dynamic HTML path.
  // A strict Content-Security-Policy is added in a later phase (see docs/architecture/backend-architecture.md).
};

export default config;
