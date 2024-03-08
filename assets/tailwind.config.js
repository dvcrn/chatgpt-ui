// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = {
	content: ["./js/**/*.js", "../lib/*_web.ex", "../lib/*_web/**/*.*ex"],
	daisyui: {
		darkTheme: "draculagpt",
		themes: [
			{
				fantasygpt: {
					"color-scheme": "light",
					primary: "oklch(37.45% 0.189 325.02)",
					secondary: "oklch(53.92% 0.162 241.36)",
					accent: "oklch(75.98% 0.204 56.72)",
					neutral: "#3D4451",
					"base-100": "#ffffff",
					"base-content": "#1f2937",
				},
				draculagpt: {
					"color-scheme": "dark",
					primary: "#ff79c6",
					secondary: "#bd93f9",
					accent: "#ffb86c",
					neutral: "#414558",
					"base-100": "#282a36",
					"base-content": "#f8f8f2",
					info: "#8be9fd",
					success: "#50fa7b",
					warning: "#f1fa8c",
					error: "#ff5555",
				},
			},
		],
	},
	theme: {
		extend: {
			colors: {
				brand: "#FD4F00",
			},
		},
	},
	plugins: [
		require("daisyui"),
		require("@tailwindcss/forms"),
		// Allows prefixing tailwind classes with LiveView classes to add rules
		// only when LiveView classes are applied, for example:
		//
		//     <div class="phx-click-loading:animate-ping">
		//
		plugin(({ addVariant }) =>
			addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])
		),
		plugin(({ addVariant }) =>
			addVariant("phx-click-loading", [
				".phx-click-loading&",
				".phx-click-loading &",
			])
		),
		plugin(({ addVariant }) =>
			addVariant("phx-submit-loading", [
				".phx-submit-loading&",
				".phx-submit-loading &",
			])
		),
		plugin(({ addVariant }) =>
			addVariant("phx-change-loading", [
				".phx-change-loading&",
				".phx-change-loading &",
			])
		),

		// Embeds Hero Icons (https://heroicons.com) into your app.css bundle
		// See your `CoreComponents.icon/1` for more information.
		//
		plugin(function ({ matchComponents, theme }) {
			let iconsDir = path.join(__dirname, "../priv/hero_icons/optimized");
			let values = {};
			let icons = [
				["", "/24/outline"],
				["-solid", "/24/solid"],
				["-mini", "/20/solid"],
			];
			icons.forEach(([suffix, dir]) => {
				fs.readdirSync(path.join(iconsDir, dir)).map((file) => {
					let name = path.basename(file, ".svg") + suffix;
					values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
				});
			});
			matchComponents(
				{
					hero: ({ name, fullPath }) => {
						let content = fs
							.readFileSync(fullPath)
							.toString()
							.replace(/\r?\n|\r/g, "");
						return {
							[`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
							"-webkit-mask": `var(--hero-${name})`,
							mask: `var(--hero-${name})`,
							"background-color": "currentColor",
							"vertical-align": "middle",
							display: "inline-block",
							width: theme("spacing.5"),
							height: theme("spacing.5"),
						};
					},
				},
				{ values }
			);
		}),
	],
};
