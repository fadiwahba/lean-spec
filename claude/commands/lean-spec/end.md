---
name: end
description: End a lean-spec feature by summarizing the final artifact state without advancing to another phase.
---

Run the manual lean-spec end phase for the feature slug in `$ARGUMENTS`.

Rules:
- Require a slug. If no slug is provided, ask for one.
- Read:
  - `lean-spec/features/<slug>/spec.md`
  - `lean-spec/features/<slug>/notes.md`
  - `lean-spec/features/<slug>/review.md`
- The default session agent owns workflow closure and status reporting.
- Do not invent approval. Report the artifact state exactly as it exists.
- Do not modify `spec.md`, `notes.md`, or `review.md` unless the human explicitly requested a final cleanup edit.

Report:
- current feature status from `spec.md`
- remaining unchecked tasks
- open notes
- open review findings
- whether the feature looks ready to stop
- any obvious follow-up command if the feature is not actually complete

Keep the response compact and operational.
