# Feature: Header, Footer & Main Navigation

## Slug
`header-footer-main-nav`

## Created At
`2026-04-10 00:40 NZST`

## Updated At
`2026-04-10 01:22 NZST`

## Status
`done`

## Goal
Add a persistent, animated header with logo, main navigation, user icon, and theme toggle, plus a dark footer with copyright and social media icons — giving the todo app a complete, polished shell that matches its indigo/violet visual language.

## Visual Direction

**Color scheme:**
- Light mode: header uses `bg-white/80` with `backdrop-blur`, indigo/violet text and accent colors, `border-b border-slate-200/60`; footer uses `bg-slate-900` with `text-slate-400`
- Dark mode: header uses `bg-slate-900/80` with `backdrop-blur`; footer stays `bg-slate-950`; body background inverts to a dark gradient

**Header:**
- Sticky, full-width, `h-16`
- Subtle gradient underline or `shadow-sm` on scroll (scroll-aware via `useScroll` or `useState` + scroll listener)
- Logo left-aligned; nav center (desktop) or hidden behind hamburger (mobile); icon group right-aligned

**Footer:**
- Dark background (`bg-slate-900`), `py-8`, centered layout
- Muted copyright text + social icon row with hover color transitions

**Animation principles:**
- Header: slides down from `-translate-y-full` on mount (`initial → animate`, duration 0.4s, ease `easeOut`)
- Footer: fades in (`opacity: 0 → 1`, duration 0.5s, slight `y` offset)
- Theme toggle icon: `AnimatePresence` crossfade between sun and half-moon icons (duration 0.2s)
- Nav links: subtle `hover` underline slide-in using Tailwind `group` / `after:` pseudo-element or framer `whileHover`
- No layout-breaking animations; all motion respects `prefers-reduced-motion`

## Scope

**Header:**
- `SiteHeader` component: logo (text-based with indigo gradient or `next/image`), main nav links (Home, About — placeholder links), user icon button (links to `/login` stub route), theme toggle button
- Nav collapses to hamburger on `< md` breakpoint; drawer or dropdown menu on mobile

**Footer:**
- `SiteFooter` component: copyright line (`© {year} TodoApp`), social icons row (GitHub, Twitter/X, LinkedIn) as icon-only links
- Icons sourced from `lucide-react` (already bundled with shadcn/ui)

**Theme toggle:**
- Persisted via `localStorage` using `next-themes`; `ThemeProvider` wraps `<body>` in `layout.tsx`
- SSR-safe: `suppressHydrationWarning` on `<html>`; toggle button renders after mount (`useEffect` guard) to avoid hydration flash
- Two states: `Sun` icon (light mode active), `MoonStar` icon (dark mode active)

**Layout integration:**
- `app/layout.tsx` updated: wrap body children with `ThemeProvider`, insert `<SiteHeader />` before `{children}` and `<SiteFooter />` after
- `app/page.tsx` `<div>` padding/centering preserved; `min-h-screen` shifts to a flex column on the body

**Responsive:**
- Header: desktop horizontal nav; mobile hamburger → slide-down nav drawer
- Footer: single-column centered on all breakpoints

## Non-Goals
- Authentication implementation (user icon is a UI stub only; no login flow)
- Multi-language / i18n support
- Footer page links (sitemap, privacy policy, etc.)
- Mega-menu or multi-level navigation
- Server-side Zustand state for theme (client-side `localStorage` via `next-themes` is sufficient)
- Custom icon library (use `lucide-react` exclusively)

## Constraints
- Next.js 15 App Router — layout components must be compatible with RSC boundaries; interactive parts (`ThemeProvider`, toggle button, mobile menu) must be `"use client"` components
- Tailwind CSS v4 — use `@source` directives in `globals.css` to pick up new component paths; no `tailwind.config.js` to modify
- shadcn/ui — use `Button` (with `variant="ghost"` and `size="icon"`) for icon buttons; do not reinvent primitives
- framer-motion — import from `framer-motion`; use `motion.*` wrappers on structural elements only; keep animation logic colocated
- `next-themes` must be added as a dependency (`pnpm add next-themes`)
- No new Zustand stores for theme; `next-themes` `useTheme` hook covers all state needs
- `lucide-react` already available via shadcn/ui install

## Implementation Notes

**File structure (new files):**
```
components/
  layout/
    site-header.tsx        # "use client" — sticky header with scroll shadow, nav, icons
    site-footer.tsx        # "use client" — dark footer with social icons
    mobile-nav.tsx         # "use client" — hamburger-triggered nav drawer (md: hidden)
    theme-toggle.tsx       # "use client" — AnimatePresence icon swap, useTheme
    theme-provider.tsx     # "use client" — wraps next-themes ThemeProvider
```

**`app/layout.tsx` changes:**
- Add `suppressHydrationWarning` to `<html>`
- Wrap body content in `<ThemeProvider attribute="class" defaultTheme="system" enableSystem>`
- Body className: flex column, `min-h-screen`; header and footer sit outside page scroll content
- Add `dark:` variants to body background gradient

**Theme toggle approach:**
- `next-themes` sets `class="dark"` on `<html>`; Tailwind v4 uses `@variant dark (&:is(.dark *))` or the standard `dark:` prefix (confirm Tailwind v4 dark mode config — may need `darkMode: 'class'` equivalent)
- Toggle reads `resolvedTheme` from `useTheme`; renders after mount to avoid flash

**Animation strategy:**
- `SiteHeader`: `motion.header` with `initial={{ y: -64, opacity: 0 }}`, `animate={{ y: 0, opacity: 1 }}`
- `SiteFooter`: `motion.footer` with `initial={{ opacity: 0, y: 16 }}`, `animate={{ opacity: 1, y: 0 }}`
- Both use `viewport={{ once: true }}` pattern or mount-time animation (header always mounts at page load)
- `ThemeToggle`: `AnimatePresence mode="wait"` wraps `motion.span` keyed by theme value

## Task Checklist

- [ ] Install `next-themes` dependency (`pnpm add next-themes`)
- [ ] Create `components/layout/theme-provider.tsx`
- [ ] Update `app/layout.tsx`: add `ThemeProvider`, `suppressHydrationWarning`, flex-column body, dark gradient variants
- [ ] Create `components/layout/theme-toggle.tsx` with `AnimatePresence` icon swap
- [ ] Create `components/layout/site-header.tsx` (logo, desktop nav, icon group, scroll shadow)
- [ ] Create `components/layout/mobile-nav.tsx` (hamburger button, slide-down drawer, nav links)
- [ ] Create `components/layout/site-footer.tsx` (dark bg, copyright, social icon links)
- [ ] Wire `<SiteHeader />` and `<SiteFooter />` into `app/layout.tsx`
- [ ] Update `app/globals.css` `@source` to include `components/layout/**`
- [ ] Verify dark mode class toggling works (Tailwind v4 dark mode configuration)
- [ ] Test responsive behavior: desktop nav visible, mobile hamburger visible, drawer opens/closes
- [ ] Test theme persistence: toggle survives page reload; system preference respected on first load
- [ ] Polish: scroll shadow on header, hover states on nav links and social icons, reduced-motion compliance

## Acceptance Criteria

- Header is visible and sticky on all pages; scrolling content passes beneath it without overlap
- Logo, nav links, user icon button, and theme toggle are present and keyboard-accessible in the header
- Theme toggle switches between light and dark mode; selection persists across page reloads
- On viewport `< md`: nav links are hidden; hamburger button is visible and opens a nav drawer
- On viewport `>= md`: hamburger is hidden; nav links are visible inline
- Footer is visible below page content with dark background, copyright text, and at least 2 social icon links
- Header entrance animation plays once on mount (slides down); footer fades in on mount
- Theme toggle icon animates between sun and half-moon with a crossfade
- No hydration mismatch errors in the browser console
- All interactive elements (toggle, nav links, social icons, hamburger) have visible focus rings
- Animations are suppressed when `prefers-reduced-motion: reduce` is active

## Change Log
- `2026-04-10 00:40 NZST`: initial spec file created (placeholder)
- `2026-04-10 00:49 NZST`: full spec drafted — scope, visual direction, constraints, task checklist, and acceptance criteria defined
