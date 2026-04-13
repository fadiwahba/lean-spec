# Feature: Todo App with Zustand

## Slug
`todo-app-zustand`

## Created At
`2026-04-09 23:04 NZST`

## Updated At
`2026-04-10 02:18 NZST`

## Status
`done`

## Goal
A polished, accessible single-page todo application built with Next.js 15, Zustand, and shadcn/ui that lets users add, complete, delete, and filter tasks — with state persisted to localStorage so todos survive page refreshes.

---

## Visual Direction

**Color palette:** Indigo/violet primary (`indigo-500` / `violet-500`) against a warm off-white background (`slate-50`). Completed todos render in `slate-400`. Filter pills use `indigo-100` fill with `indigo-700` text when active. Avoid pure black or pure white as dominant surfaces.

**Typography:** Inter or Geist Sans (Next.js default). Heading at `text-2xl font-semibold tracking-tight`. Todo text at `text-base`. Filter labels at `text-sm font-medium`.

**Surfaces:** Single card container with `rounded-2xl`, `shadow-md`, `border border-slate-200`, `bg-white`. Input uses `rounded-xl` with a subtle `ring-indigo-400` focus ring.

**Gradients:** Page background uses a soft radial or linear gradient: `from-indigo-50 via-white to-violet-50`. The card header area can use a very light `bg-gradient-to-b from-indigo-50 to-white`.

**Motion principles:**
- Page load: card fades and slides up (`opacity-0 → 1`, `translateY(16px) → 0`), 300 ms ease-out.
- Add todo: new item animates in from `opacity-0, translateY(-8px)`, 200 ms ease-out.
- Toggle complete: strikethrough and color change transition over 150 ms. Checkbox scale pulse on check (`scale(1.2) → scale(1)`), 120 ms.
- Delete: item fades out and collapses height, 150 ms ease-in, then removed from DOM.
- Filter change: active pill transitions background with `transition-colors`, 150 ms. List cross-fades or re-renders with a subtle opacity transition.
- Use Tailwind `transition`, `duration-*`, and `ease-*` utilities. For mount/unmount animations use `framer-motion` (AnimatePresence + motion.li).

**Accessibility:** Sufficient contrast (WCAG AA minimum). All interactive elements keyboard-focusable. Checkbox uses `aria-label`. Delete button uses `aria-label="Delete [todo text]"`. Filter buttons use `aria-pressed`. Live region (`aria-live="polite"`) announces filter changes and item counts.

---

## Scope

### Core features
- **Add todo:** Text input + submit button. Trim whitespace; reject empty strings. Submit on Enter or button click.
- **Toggle complete:** Checkbox per todo item. Toggles `completed` boolean on the item.
- **Delete todo:** Icon button per todo item. Removes item from list.
- **Filter:** Three filter options — All, Active, Completed. Filters the visible list without removing items.
- **Item count:** Display "N item(s) left" below the list, reflecting active (incomplete) count.
- **LocalStorage persistence:** Full todo list (id, text, completed) persisted via Zustand `persist` middleware with `createJSONStorage(() => localStorage)`.

### UI / UX
- Responsive single-column layout, centered, max-width `max-w-lg` on desktop.
- Empty state message per filter (e.g. "No active todos — enjoy your day.").
- Keyboard-accessible throughout (Tab, Enter, Space).
- Screen reader support via ARIA labels and live regions.
- Animations as described in Visual Direction.

---

## Non-Goals
- Server-side persistence (database, API, cloud sync)
- User authentication or multi-user support
- Todo editing (clicking to rename an existing item)
- Due dates, priorities, tags, or categories
- Drag-and-drop reordering
- Dark mode
- PWA / offline support beyond localStorage

---

## Constraints

- **Framework:** Next.js 15, App Router, TypeScript strict mode
- **State:** Zustand v5 with `persist` middleware (`zustand/middleware`)
- **UI components:** shadcn/ui (latest, `npx shadcn@latest init -t next`)
- **Styling:** Tailwind CSS v3 (bundled with shadcn init)
- **Animation:** `framer-motion` for mount/unmount; Tailwind utilities for static transitions
- **Package manager:** `pnpm` exclusively — no `npm` or `yarn` invocations
- **Project root:** App lives at the repository root (not in a subdirectory)
- **Node:** Compatible with current LTS (v20+)
- **No server components for interactive UI** — the page component must be a Client Component (`'use client'`) or delegate to a client wrapper; the root layout remains a Server Component

---

## Implementation Notes

### File structure
```
app/
  layout.tsx          # Root layout — metadata, font, global styles
  page.tsx            # Thin shell, renders <TodoApp />; 'use client' at component level
  globals.css         # Tailwind base + CSS custom properties

components/
  todo-app.tsx        # Main client component — composes all sub-components
  todo-input.tsx      # Controlled input + add button
  todo-list.tsx       # AnimatePresence wrapper + list of todo-item
  todo-item.tsx       # Single row: checkbox, text, delete button
  todo-filter.tsx     # All / Active / Completed filter pills
  todo-footer.tsx     # Item count + filter (or footer area)

store/
  use-todo-store.ts   # Zustand store with persist middleware

types/
  todo.ts             # Todo interface, FilterType union
```

### Zustand store shape
```ts
// types/todo.ts
export interface Todo {
  id: string        // crypto.randomUUID()
  text: string
  completed: boolean
}

export type FilterType = 'all' | 'active' | 'completed'

// store/use-todo-store.ts
interface TodoState {
  todos: Todo[]
  filter: FilterType
  addTodo: (text: string) => void
  toggleTodo: (id: string) => void
  deleteTodo: (id: string) => void
  setFilter: (filter: FilterType) => void
}
```

### Persistence
- Use `persist` + `createJSONStorage(() => localStorage)` from `zustand/middleware`.
- Persist key: `'todo-app-storage'`.
- Persist only `todos` (use `partialize`); `filter` resets to `'all'` on reload.
- **v5 caveat:** `persist` no longer auto-writes initial state at store creation. Explicit `setState` is only needed for dynamic initial values — static defaults (`todos: []`) are fine.

### shadcn/ui components to install
```bash
pnpm dlx shadcn@latest add button input checkbox badge
```
Use `Button` for add and delete actions, `Input` for the text field, `Checkbox` for completion toggle, `Badge` for filter pills (or style with Tailwind if Badge variant doesn't fit).

### Animation approach
- Wrap `<ul>` content with `<AnimatePresence mode="popLayout">`.
- Each `<motion.li>` uses `initial`, `animate`, `exit` props for add/delete transitions.
- Page card uses `motion.div` with `initial={{ opacity: 0, y: 16 }}`.
- Keep `framer-motion` imports in Client Components only.

---

## Task Checklist

### Project setup
- [x] `pnpm create next-app@latest . --typescript --tailwind --eslint --app --src-dir=false --import-alias="@/*"` at repo root
- [x] `pnpm dlx shadcn@latest init -t next` — accept defaults, use Neutral or Slate base color
- [x] `pnpm dlx shadcn@latest add button input checkbox badge`
- [x] `pnpm add framer-motion zustand`
- [x] Verify `tsconfig.json` has `"strict": true`

### Types and store
- [x] Create `types/todo.ts` — `Todo` interface, `FilterType` union
- [x] Create `store/use-todo-store.ts` — Zustand store with `persist` middleware, `partialize` to exclude `filter`

### Components
- [x] `components/todo-input.tsx` — controlled input, add on Enter/button, trims and rejects empty
- [x] `components/todo-item.tsx` — checkbox (toggle), text (strikethrough when complete), delete button with aria-label
- [x] `components/todo-filter.tsx` — All / Active / Completed pills with `aria-pressed`
- [x] `components/todo-footer.tsx` — active item count with `aria-live="polite"`
- [x] `components/todo-list.tsx` — `AnimatePresence` + `motion.li` per item, empty state message
- [x] `components/todo-app.tsx` — composes all sub-components, derives filtered list from store

### Layout and page
- [x] `app/layout.tsx` — metadata (`title: 'Todos'`), Geist/Inter font via `next/font`, import `globals.css`
- [x] `app/page.tsx` — renders `<TodoApp />`, page background gradient applied here or in layout body class
- [x] `app/globals.css` — Tailwind directives, CSS custom properties if needed

### Polish and accessibility
- [x] Apply page background gradient (`from-indigo-50 via-white to-violet-50`)
- [x] Card: `rounded-2xl shadow-md border border-slate-200 bg-white`
- [x] Input focus ring: `ring-indigo-400`
- [x] Motion: page load animation on card, add/delete/toggle animations on items, filter pill transition
- [x] ARIA: `aria-label` on all icon buttons, `aria-pressed` on filter buttons, `aria-live` on footer count
- [x] Keyboard: Tab through all controls, Enter to add, Space to toggle checkbox, Delete button reachable
- [x] Empty state per filter variant

### Verification
- [x] Add several todos, refresh — todos persist
- [x] Filter All / Active / Completed — correct items shown
- [x] Toggle complete — strikethrough + style change, count updates
- [x] Delete — item removed with exit animation
- [x] Keyboard-only walkthrough — all actions reachable

---

## Acceptance Criteria

1. Adding a todo appends it to the list and clears the input; empty/whitespace-only input is rejected without error state.
2. Checking a todo marks it complete (strikethrough, muted color); unchecking restores it. Active count updates immediately.
3. Deleting a todo removes it from all filters permanently.
4. Filtering to Active shows only incomplete todos; Completed shows only complete todos; All shows everything.
5. Refreshing the page restores all todos and their completion state; filter resets to All.
6. All interactive controls are reachable and operable via keyboard alone (Tab, Enter, Space).
7. Delete and filter buttons have descriptive `aria-label` / `aria-pressed` attributes visible to screen readers.
8. The footer announces updated item count to screen readers via `aria-live="polite"`.
9. Page background, card, and filter pills use the indigo/violet palette — no plain black-on-white default appearance.
10. Add, delete, toggle, and page load animations are visible and complete without jank; no layout shift.

---

## Change Log
- `2026-04-09 23:04 NZST`: initial spec created
- `2026-04-09 23:13 NZST`: full spec written — visual direction, scope, store shape, file structure, task checklist, acceptance criteria
