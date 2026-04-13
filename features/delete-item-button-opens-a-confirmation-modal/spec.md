# Feature: Delete Item Button Opens a Confirmation Modal

## Slug
`delete-item-button-opens-a-confirmation-modal`

## Created At
`2026-04-10 13:31 NZST`

## Updated At
`2026-04-10 13:35 NZST`

## Status
`done`

---

## Goal

When the user clicks the trash-can delete button on any todo item, a confirmation modal opens asking them to confirm before the item is permanently removed.

---

## Scope

- Clicking the `Trash2` icon button in `TodoItem` opens a controlled Radix UI Dialog.
- The modal displays the todo item's text in the confirmation message.
- The modal provides two actions: **Cancel** (closes without deleting) and **Delete** (calls `deleteTodo` and closes).
- Closing the dialog via the Radix overlay click or Escape key is treated as Cancel.
- The modal uses the existing `DialogContent` / `DialogHeader` / `DialogFooter` / `DialogTitle` / `DialogDescription` primitives from `components/ui/dialog.tsx`.
- Buttons use the existing `Button` component with `variant="outline"` (Cancel) and `variant="destructive"` (Delete).
- The modal inherits light/dark theme automatically via the existing Tailwind dark-mode class strategy (`ThemeProvider` sets `class` attribute on `<html>`).
- The `DialogContent` built-in close button (`X`) remains present (Radix default).

---

## Non-Goals

- Undo / restore after deletion.
- Bulk delete with a single confirmation.
- Custom animation beyond what Radix UI Dialog and `components/ui/dialog.tsx` already provide (zoom-in/fade-in on open, zoom-out/fade-out on close).
- Persisting "modal open" state to the Zustand store or URL.
- Any new npm dependencies.

---

## Constraints

- Use `@radix-ui/react-dialog` exclusively via the existing `components/ui/dialog.tsx` wrappers — do not import from Radix primitives directly in feature components.
- No new dependencies may be added to `package.json`.
- Theming must follow the existing pattern: Tailwind `dark:` variants driven by the `class` attribute on `<html>` set by `next-themes` via `ThemeProvider` in `app/layout.tsx`.
- `DeleteConfirmModal` is a controlled component: open state lives in `TodoItem` via `useState`, not in Zustand.
- The Zustand `deleteTodo(id: string)` action is the only mutation called on confirm.

---

## Implementation Notes

### Files to create

| File | Purpose |
|---|---|
| `components/delete-confirm-modal.tsx` | Controlled modal component wrapping `Dialog` primitives |

### Files to modify

| File | Change |
|---|---|
| `components/todo-item.tsx` | Add `modalOpen` state; wire delete button click to open modal; render `<DeleteConfirmModal>` |

### Component design — `DeleteConfirmModal`

```tsx
interface DeleteConfirmModalProps {
  todoText: string   // displayed in the confirmation message
  open: boolean      // controlled by parent
  onConfirm: () => void  // parent calls deleteTodo then closes
  onCancel: () => void   // parent closes without deleting
}
```

- Renders a `<Dialog open={open} onOpenChange>` where `onOpenChange(false)` maps to `onCancel`.
- `DialogContent` uses `sm:max-w-[425px]`.
- `DialogTitle`: "Delete todo?"
- `DialogDescription`: `Are you sure you want to delete "{todoText}"? This cannot be undone.`
- `DialogFooter` contains Cancel (`variant="outline"`) then Delete (`variant="destructive"`), in that DOM order (Radix reverses visually on mobile via `flex-col-reverse`).

### Wiring in `TodoItem`

```tsx
const [modalOpen, setModalOpen] = useState(false)

const handleDeleteClick = () => setModalOpen(true)
const handleConfirmDelete = () => { setModalOpen(false); onDelete(todo.id) }
const handleCancelDelete = () => setModalOpen(false)
```

The existing `onDelete` prop received by `TodoItem` already calls `useTodoStore`'s `deleteTodo` — no changes needed to `todo-app.tsx` or the Zustand store.

### Theme compliance

`DialogContent` in `components/ui/dialog.tsx` already declares:
- Light: `bg-white border-slate-200`
- Dark: `dark:bg-slate-950 dark:border-slate-800`

`Button` variants `outline` and `destructive` already declare equivalent dark overrides. No additional Tailwind classes are required on the modal.

---

## Task Checklist

- [x] Create `components/delete-confirm-modal.tsx` with the controlled `DeleteConfirmModal` component.
- [x] Add `useState(false)` for `modalOpen` in `components/todo-item.tsx`.
- [x] Replace the direct `onDelete` call on the delete button with `handleDeleteClick` that sets `modalOpen = true`.
- [x] Render `<DeleteConfirmModal>` below the `<motion.li>` inside the fragment in `TodoItem`.
- [x] Verify the modal opens on delete-button click in both light and dark mode.
- [x] Verify Cancel and Escape/overlay-click close the modal without deleting the item.
- [x] Verify Delete removes the item and closes the modal.
- [x] Verify the todo text is correctly quoted in the modal description.

---

## Acceptance Criteria

1. Clicking the trash-can button on a todo item opens the confirmation modal — the item is **not** deleted immediately.
2. The modal title reads "Delete todo?" and the description includes the exact todo item text in quotes.
3. Clicking **Cancel** dismisses the modal; the item remains in the list.
4. Pressing **Escape** or clicking the backdrop dismisses the modal; the item remains in the list.
5. Clicking **Delete** removes the item from the list and closes the modal.
6. In light mode the modal background is white (`bg-white`) with a slate border; in dark mode it is `slate-950` with a `slate-800` border — matching the existing dialog primitive styles.
7. The modal open/close transition uses the zoom-in/fade-in and zoom-out/fade-out animations already defined in `DialogContent`.
8. No new npm packages appear in `package.json` after implementation.

---

## Change Log

- 2026-04-10: initial spec created; implementation partially complete (modal component and TodoItem wiring already exist).
