# Cherry Soda Club backend

GitHub Pages hosts the frontend. Supabase project `aqessidqzmekfigbglkc` stores public club content, records, images, and private membership bindings. The browser uses only its publishable key.

Apply SQL in this order on a fresh project: `backend.sql`, `backend-auth.sql`, `seed.sql`, `backend-publish.sql`, `backend-safety.sql`. These scripts are provisioning snapshots, not rerunnable migrations. Configure the verified owner's email mapping only in the private `owner_binding` table; do not commit that email or any privileged API key. `backend-publish-fix.sql` records the publishing correction used during setup. `backend-storage-fix.sql` limits bucket listing to the owner/member and prevents public access to author account IDs.

Keep email confirmation enabled. The private owner mapping depends on genuine verified-email ownership. A nickname request never grants membership automatically. The owner reviews requests and links the verified account to an existing member. Default Supabase SMTP can only send to organization team addresses, so custom SMTP is required before inviting the other club members. No service-role key is needed in frontend files.

`verify-security.sql` checks ownership and admin access using transaction-local fixtures and rolls everything back. `backend-delete-fix.sql` preserves private creator/admin visibility for soft deletion. Member records are soft deleted; the owner can restore them from the account screen. Club content publishing checks the revision and updates its document plus managed records in one database transaction.

Public records are joined with existing JSON records, then rendered in the home page, record list, member cards, and linked theme archive. Open public pages refresh after tab focus and at 30-second intervals. Same-browser saves notify other tabs immediately.

SDK: vendored `@supabase/supabase-js` version 2.117.3, with its upstream MIT license in `SUPABASE-LICENSE.txt`.

## Halloween 2026

`halloween.html` uses the existing login and membership binding. Apply
`backend-halloween.sql` once in the existing project's SQL Editor. It is
transactional and can be rerun without resetting submissions or phase. A signed-in
owner sees the setup copy button while the RPC is absent.

The host supplies missions in the event screen (one per line, up to 50). No
default missions are seeded. The list locks when the first participant receives
a mission; all candidate mission labels become visible only during guessing.

All assignments, submissions, compressed images and ballots live in private
RLS-enabled tables with no direct visitor grants. Images are re-encoded in the
browser to remove file metadata and stored in private event rows (one compressed
image, at most 2 MB encoded per entry, suitable for this small club event).
The existing public record feed and image bucket are never used for this event.
The authenticated RPC returns only the caller's private data and the gallery
fields allowed by the current phase. Before reveal, author and assigned mission
fields are never returned to other participants. The host can inspect assignments
and is excluded from the leaderboard.

The host advances collecting → guessing → revealed on the event page. Opening
means all submitted images become visible to signed-in, registered club members;
it also locks submission editing. Reveal closes ballots and discloses authors,
missions and scores. October 31 is the intended reveal date, not an unattended
scheduler. One mission per club member, one ballot per member/work; withdrawal
retains the mission to prevent rerolls. Each correct author and mission is worth
one point, self-votes are disallowed, and ties share a rank.

Validation: the SQL was installed in an isolated PostgreSQL-compatible PGlite
runtime, testing member access, private-table denial, unique assignments,
withdrawal/resubmission, phase restrictions, redacted gallery payloads, private
ballots, vote upserts, scoring, and host exclusion. The live database installation and authenticated state RPC were also verified.
