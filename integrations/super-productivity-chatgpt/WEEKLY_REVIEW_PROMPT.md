Create a weekly scheduled task named “Weekly project reconciliation” for Mondays at 09:00 America/Bogota, returning results to this chat. Use the attached super-productivity MCP connection. Run the review once now to verify tool access. Only say the schedule is created after scheduling is confirmed; if connected tools are unavailable to scheduled runs, explain that limitation instead of creating a misleading sync task.

Review HACKATHONS, TESIS, LSTS, HASHPASS and JACK-K, plus Inbox. Resolve their exact Super Productivity IDs using list_projects, read get_project_brief for each, and preserve the established ID mappings in their shared briefs. Flag missing or ambiguous projects instead of creating or guessing matches. Paginate search_tasks to obtain all relevant tasks.

Each week:
1. Read live tasks and shared briefs. Report open/completed work, existing deadlines, and changes since the last successful review in this chat. Use exact task IDs. The first run establishes a baseline; missing tasks are not necessarily deleted. Never invent priorities, deadlines or progress.
2. Compare only with ChatGPT context actually available in this conversation. You cannot automatically read every private ChatGPT Project or discover newly created Projects. Ask for missing context when necessary.
3. Suggest mappings for Inbox tasks and identify stale or duplicate work. Leave archived projects and tasks intact. Do not create, move, complete, archive or delete tasks during this review without a separate explicit instruction.
4. Update a clearly labelled, dated “Weekly progress” section in each shared brief using save_project_brief and its current context.revision. Preserve existing goals, decisions, links and bindings. Reread and reconcile revision conflicts instead of overwriting them.
5. Return a short report of changes, proposed mappings, blockers and next actions. Report connection failures explicitly; never present a cached snapshot as a successful live read.

For later explicitly authorized task edits, read get_task first, use its expectedRevision and a durable unique requestId, and verify the result. Reuse the same requestId for an identical retry; investigate uncertain writes before retrying with a new ID.

This is a weekly review with shared-brief updates, not automatic replication of ChatGPT files or conversations. My bridge computer, Super Productivity and tunnel must be running.
