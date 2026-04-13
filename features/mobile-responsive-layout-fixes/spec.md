# Feature: Mobile Responsive Layout Fixes

## Slug
`mobile-responsive-layout-fixes`

## Created At
`2026-04-10`

## Updated At
`2026-04-10 14:02 NZST`

## Status
`done`

## Goal

Fix all layout and styling breakdowns visible at 375 px (iPhone 14) so the todo app is fully usable and polished on mobile — no edge-to-edge dialogs, no awkward button stacks, no dead vertical space.

---

## Scope

Five concrete issues confirmed by Playwright audit at 375 × 812 px.

### Issue 1 — Delete confirmation modal spans edge-to-edge on mobile

**Observed:** The dialog panel renders flush to both screen edges (left: 0, right: 375, width: 375 px). The `sm:rounded-lg` guard means corners are only rounded above 640 px; below that the modal is a sharp rectangle with zero horizontal margin.

**Fix:** In `components/ui/dialog.tsx`, on `DialogContent` replace `sm:rounded-lg` with `rounded-lg` (unconditional) and add `mx-4` to give 16 px side margins.

### Issue 2 — Dialog footer buttons stack in counter-intuitive order on mobile

**Observed:** `DialogFooter` uses `flex-col-reverse`, which puts the destructive "Delete" button visually above "Cancel" on mobile — the opposite of the expected primary-last convention for stacked actions.

**Fix:** In `components/ui/dialog.tsx`, on `DialogFooter` change `flex-col-reverse` to `flex-col` so Cancel appears first (top) and Delete appears second (bottom) in both DOM and visual order. Desktop layout (`sm:flex-row sm:justify-end sm:space-x-2`) is unchanged.

### Issue 3 — Dialog header text is centered on mobile, mismatching the rest of the UI

**Observed:** `DialogHeader` carries `text-center sm:text-left`. On mobile the title and description are centered while all surrounding UI is left-aligned, creating a visual inconsistency.

**Fix:** In `components/ui/dialog.tsx`, on `DialogHeader` remove `text-center`, keeping only `sm:text-left` (which makes it left-aligned at all breakpoints, since there is no centering override below `sm`).

### Issue 4 — Todo card floats mid-screen when the list is short

**Observed:** `app/page.tsx` wraps `<TodoApp>` with `flex items-center justify-center`, which vertically centres the card in the main area. With a short list the card sits in the middle of a large blank space, leaving the footer marooned at the very bottom.

**Fix:** In `app/page.tsx` change `items-center` to `items-start` so the card aligns to the top of the main content area on all screen sizes. Horizontal centering and all padding values are preserved.

### Issue 5 — Mobile nav drawer blends into page background in dark mode

**Observed:** The nav drawer (`components/layout/mobile-nav.tsx`) has `bg-white dark:bg-slate-900 border-b` but no shadow and no rounded bottom corners. In dark mode its background is nearly identical to the page body (`dark:bg-slate-900`/`dark:from-slate-950`), making it visually indistinct.

**Fix:** Add `shadow-md rounded-b-lg` to the drawer `motion.div` in `components/layout/mobile-nav.tsx`.

---

## Non-Goals

- Visual redesign, color palette changes, or new design tokens
- Desktop layout changes (fixes must not touch behavior above `sm`/`md` breakpoints)
- New features, routes, or components
- Animation or transition changes
- Semantically incorrect social icon choices in `SiteFooter` (out of scope for a layout fix)

---

## Constraints

- Tailwind CSS v4 only — no new CSS files, inline styles, or third-party packages
- Preserve all existing design tokens (colors, radii, spacing scale); only add or swap utility classes
- No changes to Radix UI primitive configuration beyond `cn()` class overrides
- Fixes must not regress desktop layout (visually verify at 1280 px after applying each change)

---

## Implementation Notes

### `components/ui/dialog.tsx`

**DialogContent** base class string — key changes:
- `sm:rounded-lg` → `rounded-lg`
- Add `mx-4`

Resulting relevant segment:
```
"fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border border-slate-200 bg-white p-6 shadow-lg rounded-lg mx-4 duration-200 ... dark:border-slate-800 dark:bg-slate-950"
```

**DialogFooter** class string — change:
```
"flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2"
```
to:
```
"flex flex-col sm:flex-row sm:justify-end sm:space-x-2"
```

**DialogHeader** class string — change:
```
"flex flex-col space-y-1.5 text-center sm:text-left"
```
to:
```
"flex flex-col space-y-1.5 sm:text-left"
```

### `app/page.tsx`

Change the wrapper div class:
```tsx
// before
<div className="flex items-center justify-center p-4 py-8">
// after
<div className="flex items-start justify-center p-4 py-8">
```

### `components/layout/mobile-nav.tsx`

Add `shadow-md rounded-b-lg` to the drawer `motion.div` className:
```
"absolute left-0 right-0 top-16 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 shadow-md rounded-b-lg md:hidden z-40"
```

---

## Task Checklist

- [x] `components/ui/dialog.tsx` — `DialogContent`: replace `sm:rounded-lg` with `rounded-lg`, constrain width with `max-w-[calc(100%-3rem)] sm:max-w-lg` (Issue 1)
- [x] `components/ui/dialog.tsx` — `DialogFooter`: change `flex-col-reverse` to `flex-col` (Issue 2)
- [x] `components/ui/dialog.tsx` — `DialogHeader`: remove `text-center` (Issue 3)
- [x] `app/page.tsx` — change `items-center` to `items-start` (Issue 4)
- [x] `components/layout/mobile-nav.tsx` — add `shadow-md rounded-b-lg` to drawer (Issue 5)
- [x] `components/ui/dialog.tsx` — `DialogContent`: raise dark mode background from `dark:bg-slate-950` to `dark:bg-slate-800` and border to `dark:border-slate-700` for contrast (Issue 6)
- [x] `components/ui/dialog.tsx` — `DialogFooter`: add `gap-2` between stacked buttons on mobile (Issue 7)

---

## Acceptance Criteria

All criteria verified at 375 × 812 px viewport.

1. **Modal margins:** The delete confirmation dialog has visible side margins (≥ 16 px each side) and rounded corners at all sizes — it does not span edge-to-edge on a 375 px screen.
2. **Button order:** In the modal on mobile, "Cancel" appears visually above "Delete" when the buttons are stacked vertically.
3. **Modal header alignment:** The "Delete todo?" title and description are left-aligned on mobile (not centered).
4. **Card vertical position:** The todo card is flush to the top of the main content area (directly below the header) rather than vertically centred — no large dead space between card and footer on a short list.
5. **Mobile nav drawer:** The nav drawer has a visible bottom shadow and rounded bottom corners in both light and dark mode, making it visually distinct from the page background.
6. **Modal dark mode contrast:** In dark mode, the modal background is visibly lighter than the page (`dark:bg-slate-800`) — the modal panel clearly stands out against the near-black backdrop.
7. **Button gap:** Cancel and Delete buttons have visible spacing between them when stacked on mobile (≥ 8px gap).

## Change Log
- 2026-04-10: initial spec created (template)
- 2026-04-10 13:41 NZST: full spec written from Playwright mobile audit — 5 issues identified and specced
