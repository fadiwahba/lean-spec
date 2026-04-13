# Notes: Todo App with Zustand

## Created At
`2026-04-09 22:10 NZST`

## Updated At
`2026-04-10 01:36 NZST`

## Status
`closed` (all items resolved and validated)

---

## Summary

Rendering regression detected on 2026-04-10 and fully resolved through lean-spec lifecycle:

- **lean-architect**: Diagnosed root causes (Tailwind v4 styling, layout, dark mode infrastructure)
- **lean-coder**: Implemented fixes across 5 component and layout files
- **header-footer-main-nav**: Applied global dark mode directive fix
- **User validation**: Confirmed all fixes with rendered screenshots
- **Visual enhancements**: Updated card/text styling per user feedback

All acceptance criteria pass. Feature complete.

---

## Resolved Items

### ✅ N1: Add button indigo styling conflict (F-12)
- **Root cause:** Tailwind utility merge conflict in shadcn Button variant
- **Fix applied:** Changed to `variant="ghost"` with `className="bg-indigo-600 hover:bg-indigo-700 text-white"`
- **Files:** `components/todo-input.tsx`
- **Status:** Resolved and validated

### ✅ N2: Checkbox invisible due to border conflict (F-13a)
- **Root cause:** Border color declarations conflicting (`border-slate-950` overriding visible color)
- **Fix applied:** Updated to `border-slate-300 dark:border-slate-600`
- **Files:** `components/ui/checkbox.tsx`
- **Status:** Resolved and validated

### ✅ N3: Delete button invisible due to icon color (F-13b)
- **Root cause:** Icon color inheritance in ghost variant not explicitly set
- **Fix applied:** Added `className="text-slate-500 hover:text-slate-700 dark:text-indigo-300 dark:hover:text-indigo-200"`
- **Files:** `components/todo-item.tsx`
- **Status:** Resolved and validated

### ✅ N4: Footer invisible until scroll (F-15)
- **Root cause:** `min-h-screen` on page wrapper forcing full viewport height
- **Fix applied:** Removed `min-h-screen`, replaced with `py-8` padding
- **Files:** `app/page.tsx`
- **Status:** Resolved and validated

### ✅ N5: Dark mode not applying to todo card (F-14)
- **Root cause:** Tailwind v4 requires `@custom-variant dark` directive for class-based dark mode
- **Fix applied:** Added `@custom-variant dark (&:where(.dark, .dark *));` to `app/globals.css`
- **Files:** `app/globals.css` (global infrastructure fix)
- **Scope note:** Resolved in `header-footer-main-nav` feature; `todo-app-zustand` inherits fix
- **Status:** Resolved and validated

---

## Visual Design Enhancements (2026-04-10 01:36 NZST)

**User feedback incorporated:**
- Card background now uses indigo/violet gradients matching design language
- Text contrast improved in dark mode for readability
- Filter buttons, footer, and empty state updated for consistency

**Light mode:**
- Card: `bg-gradient-to-br from-indigo-50 via-white to-violet-50`
- Header: `from-indigo-100 to-indigo-50`
- Text: `text-indigo-950`

**Dark mode:**
- Card: `bg-gradient-to-br from-indigo-950 via-indigo-900 to-violet-950`
- Header: `from-indigo-900 to-indigo-800`
- Text: `text-indigo-50` (active), `text-indigo-200/300` (secondary)

**Files updated:** `todo-app.tsx`, `todo-item.tsx`, `todo-list.tsx`, `todo-filter.tsx`, `todo-footer.tsx`

---

## Build Status
✅ `pnpm build` passes
✅ All acceptance criteria met
✅ Rendered validation confirmed
