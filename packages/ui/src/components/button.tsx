import type { ButtonHTMLAttributes, ReactNode } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
	children: ReactNode;
	variant?: "primary" | "secondary" | "ghost" | "danger";
	size?: "sm" | "md" | "lg";
}

/**
 * Base button component — will be styled in Phase 8.
 */
export function Button({
	children,
	variant = "primary",
	size = "md",
	...props
}: ButtonProps) {
	return (
		<button data-variant={variant} data-size={size} {...props}>
			{children}
		</button>
	);
}
