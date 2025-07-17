/** @type {import('next').NextConfig} */
const nextConfig = {
  // Disable static optimization for API routes during build
  output: 'standalone',
  
  // Skip build-time static generation for API routes
  experimental: {
    serverComponentsExternalPackages: ['@copilotkit/runtime']
  },
  
  // Ensure API routes are not pre-rendered
  trailingSlash: false,
  
  // Disable static export for API routes
  async rewrites() {
    return [];
  }
};

export default nextConfig;
