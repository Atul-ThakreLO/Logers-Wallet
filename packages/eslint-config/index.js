/**
 * @logers-wallet/eslint-config
 *
 * Thin ESLint config — Biome handles most formatting and linting.
 * This exists for tools that specifically require ESLint (e.g., Next.js).
 */
module.exports = {
	root: true,
	env: {
		browser: true,
		es2022: true,
		node: true,
	},
	parserOptions: {
		ecmaVersion: "latest",
		sourceType: "module",
	},
	rules: {},
};
