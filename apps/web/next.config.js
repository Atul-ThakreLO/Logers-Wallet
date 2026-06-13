/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: [
    "@logers/ui",
    "@logers/utils",
    "@logers/sdk",
    "@logers/wagmi-config",
    "@logers/contracts-abi",
  ],
};

module.exports = nextConfig;
