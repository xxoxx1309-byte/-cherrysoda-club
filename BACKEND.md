# Cherry Soda Club backend

GitHub Pages hosts the frontend. Supabase project `aqessidqzmekfigbglkc` stores public club content, records, images, and private membership bindings. The browser uses only its publishable key.

Apply SQL in this order on a fresh project: `backend.sql`, `backend-auth.sql`, `seed.sql`, `backend-publish.sql`, `backend-safety.sql`. These scripts are provisioning snapshots, not rerunnable migrations. Configure the verified owner's email mapping only in the private `owner_binding` table; do not commit that email or any privileged API key. `backend-publish-fix.sql` records the publishing correction used during setup. `backend-storage-fix.sql` limits bucket listing to the owner/member and prevents public access to author account IDs.

Keep email confirmation enabled. The private owner mapping depends on genuine verified-email ownership. A nickname request never grants membership automatically. The owner reviews requests and links the verified account to an existing member. Default Supabase SMTP can only send to organization team addresses, so custom SMTP is required before inviting the other club members. No service-role key is needed in frontend files.

`verify-security.sql` checks ownership and admin access using transaction-local fixtures and rolls everything back. Member records are soft deleted; the owner can restore them from the account screen. Club content publishing checks the revision and updates its document plus managed records in one database transaction.

Public records are joined with existing JSON records, then rendered in the home page, record list, member cards, and linked theme archive. Open public pages refresh after tab focus and at 30-second intervals. Same-browser saves notify other tabs immediately.

SDK: vendored `@supabase/supabase-js` version 2.117.3, with its upstream MIT license in `SUPABASE-LICENSE.txt`.
