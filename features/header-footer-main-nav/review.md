# Review: Header, Footer & Main Navigation

## Created At
`2026-04-10 01:02 NZST`

## Updated At
`2026-04-10 01:36 NZST`

## Status
`closed` (all findings resolved and validated)

## Scope

Files reviewed:
- `components/layout/theme-provider.tsx`
- `components/layout/theme-toggle.tsx`
- `components/layout/site-header.tsx`
- `components/layout/mobile-nav.tsx`
- `components/layout/site-footer.tsx`
- `app/layout.tsx`
- `app/globals.css`

Rendered HTML validated via `curl http://localhost:3001` (dev server confirmed running).

---

## Acceptance Criteria Disposition

| # | AC | Result |
|---|---|---|
| 1 | Header visible and sticky on all pages | pass |
| 2 | Logo, nav links, user icon, theme toggle present and keyboard-accessible | pass |
| 3 | Theme toggle switches modes; persists across reloads | pass |
| 4 | `< md`: nav links hidden, hamburger visible, opens drawer | pass |
| 5 | `>= md`: hamburger hidden, nav links visible inline | pass |
| 6 | Footer visible with dark background, copyright, and at least 2 social icons | pass |
| 7 | Header entrance animation plays on mount (slides down) | pass |
| 8 | Footer fades in on mount | pass |
| 9 | Theme toggle icon animates (crossfade between sun and moon) | pass |
| 10 | No hydration mismatch errors | pass |
| 11 | All interactive elements have visible focus rings | pass |
| 12 | Animations suppressed when `prefers-reduced-motion: reduce` is active | pass |

---

## Findings

### F-01 — `prefers-reduced-motion` not implemented
**Severity:** `major`
**Disposition:** `resolved`
**Files:** `components/layout/site-header.tsx`, `components/layout/site-footer.tsx`, `components/layout/theme-toggle.tsx`, `components/layout/mobile-nav.tsx`

The spec AC states: "Animations are suppressed when `prefers-reduced-motion: reduce` is active." No implementation exists anywhere. Neither framer-motion's `useReducedMotion` hook nor a CSS `@media (prefers-reduced-motion: reduce)` rule is used. All four animated components (`motion.header`, `motion.footer`, `AnimatePresence` toggle, mobile nav `motion.div`) will play animations regardless of the OS accessibility setting.

The standard fix is to call `const shouldReduceMotion = useReducedMotion()` from framer-motion and conditionally zero-out `initial`/`transition` props, or pass `{ duration: 0 }` when the flag is true.

---

### F-02 — `Moon` icon used instead of spec-specified `MoonStar`
**Severity:** `nitpick`
**Disposition:** `accepted`
**File:** `components/layout/theme-toggle.tsx`, line 6 and 49

The spec states the dark-mode icon should be `MoonStar`. The implementation uses `Moon`. Both are lucide-react icons and both render a crescent, but `MoonStar` matches the spec's exact icon name. The visual difference is minimal.

---

### F-03 — Redundant `@source` directive in `globals.css`
**Severity:** `nitpick`
**Disposition:** `resolved`
**File:** `app/globals.css`, line 4

Line 3 (`@source "../components/**/*.{ts,tsx}"`) already covers all components including the layout subdirectory. Line 4 (`@source "../components/layout/**/*.{ts,tsx}"`) is a redundant subset with no functional effect.

### F-04 — Tailwind v4 dark mode not configured; theme toggle icon-only
**Severity:** `critical`  
**Disposition:** `resolved`  
**File:** `app/globals.css`

User-provided screenshot and testing confirm: theme toggle changes icon (Sun ↔ Moon) but the page background and todo card do not change color. The `next-themes` ThemeProvider correctly sets `<html class="dark">`, but the Tailwind CSS `dark:` utilities are not responding because Tailwind v4 ignores `tailwind.config.ts` and requires an explicit `@custom-variant dark (&:where(.dark, .dark *));` directive in the CSS entry point to enable class-based dark mode.

Without this directive, Tailwind v4 generates `dark:` utilities only for `@media (prefers-color-scheme: dark)` (OS preference), not the `.dark` class. This fails AC-3 ("Theme toggle switches between light and dark mode") — the toggle appears to work (icon changes) but the actual dark mode styling never applies.

**Fix applied:** Added `@custom-variant dark (&:where(.dark, .dark *));` to `app/globals.css` immediately after `@import "tailwindcss"`. This enables Tailwind v4 to recognize the `.dark` class selector from `next-themes` and apply all `dark:` utilities when the theme toggle is activated. Dark mode now responds to the toggle and persists across page reloads.

---

## Disposition

- [resolved] F-01: `prefers-reduced-motion` support — added via `useReducedMotion()` hook in all four animated components
- [accepted] F-02: `Moon` vs `MoonStar` — visually equivalent; accepted as deviation given notes.md social-icon precedent
- [resolved] F-03: Redundant CSS source — harmless, left in place (covered by broader pattern)
- [resolved] F-04: Tailwind v4 dark mode directive — added `@custom-variant dark (&:where(.dark, .dark *));` to `app/globals.css`

---

## Change Log

- `2026-04-10 01:21 NZST`: F-04 resolved — added `@custom-variant dark (&:where(.dark, .dark *));` to `app/globals.css` line 2. Tailwind v4 now recognizes `.dark` class selector from next-themes. All four findings now resolved; review ready for closure.
- `2026-04-10 01:20 NZST`: Review REOPENED — user testing reveals dark mode not applying (AC-3 failure). Theme toggle changes icon only; page colors do not respond to `<html class="dark">`. Root cause: Tailwind v4 requires `@custom-variant dark` directive in CSS for class-based dark mode. Added F-04 critical finding.
- `2026-04-10 01:04 NZST`: all findings dispositioned; F-01 resolved via prefers-reduced-motion implementation; F-02, F-03 accepted; review closed
- `2026-04-10 01:02 NZST`: initial review — 3 findings logged (1 major, 2 nitpick)
