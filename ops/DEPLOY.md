# nostr.gwhyyy.com deployment

## Observed state, 2026-11-11

The Cloudflare-proxied domain now serves the Nostr site through a dedicated nginx
vhost. The unrelated tattoo app and its existing vhost were left intact.
Current release: `/var/www/nostr/releases/20261111-155830`, selected by
`/var/www/nostr/current`. Origin TLS and public HTTPS were verified; the new
Let's Encrypt certificate expires on 2027-02-09.

All 21 sitemap routes, metadata, discovery files and Flutter entry assets were
verified over public HTTPS. Unknown paths return 404 and HTTP redirects to HTTPS.
Interactive live Flutter verification and the renewal dry-run/reload hook remain
pending. Subsequent source review found playground disconnect/reconnect and
concurrent-session safety defects. The user chose to leave the existing demo
accessible. Corrected source now passes 423 offline SDK tests, 45 Flutter tests,
analysis and a rebuilt release. A real browser verified local signing, read-only
relay interaction, cancelled publishing and disconnect cleanup. The verified
replacement is assembled in `docs/build/`, but is not deployed yet.
Do not treat the older live playground as release-ready. Close existing demo tabs
after testing; a future deployment cannot terminate their open connections.
A later source-only correction to the low-level guide's `onEose` callback
is not yet in this deployed release. One default Python sitemap request received
403; subsequent identified requests and curl returned 200. A later robots.txt
sample returned 200 for verification, Googlebot, OAI-SearchBot and Python user
agents. This is sampled HTTP access, not proof of search indexing or universal
bot access.

The production parent directories are root-owned. For the next atomic release,
an administrator must either perform the directory creation/symlink switch or
grant `gw` write access to only `/var/www/nostr` and `/var/www/nostr/releases`.
Writable files inside the old release are not a reason to update it piecemeal.

Administrator follow-up: remove the two temporary probe files
`/var/www/certbot/probe` and `/var/www/certbot/.well-known/acme-challenge/probe`.
The temporary broad sudo grant was revoked; `/etc/sudoers.d/ship-nostr` is now an
empty root-owned file and can be removed by an administrator. Privileged access
again requires secure administrator authorization. Rotate any credential exposed
in chat or command history; do not reuse it here.

This is a static site. A Node/Flutter development-server reverse proxy would add
an unnecessary process and expose a development server. Nginx serves one assembled
release: Docusaurus at `/`, documentation at `/docs/`, Flutter Web at `/playground/`.

## Build locally

From `docs/`, use Node 22+ and run `npm ci`, `npm run build`, then `node scripts/check-site.mjs --site-only`.
Build the playground using `bash docs/scripts/build-playground.sh` from the repo
root (see `playground/README.md` for Flutter requirements). Assemble its generated
files into `docs/build/playground/` **after** building Docusaurus. Run
`node scripts/check-site.mjs` from `docs/` to check the assembled artifact. Do not deploy a
landing with a missing playground. Preview the assembled directory with
`npm run serve -- --host 127.0.0.1 --port 8899` from `docs/`.

## Approval-gated administrator steps

These are a runbook, not an automatically executed script. Obtain approval before
each production phase. Never put a sudo password in a command, file, or chat.

1. Record the existing enabled nginx sites and previous `current` symlink target.
   Create `/var/www/nostr/releases/` and `/var/www/certbot/` with appropriate
   ownership. Copy the assembled, verified build into a **new** release directory.
   Nginx's `www-data` user needs directory traversal and file read permissions.
   Never serve a directory being rebuilt.
2. Install `ops/nginx/nostr-http.conf` as
   `/etc/nginx/sites-available/nostr.gwhyyy.com` and enable a same-named symlink.
   Run `sudo nginx -t` before `sudo systemctl reload nginx` (separate commands).
   Verify a temporary ACME challenge file is retrievable through the public
   domain, then remove only that test file. Bootstrap deliberately returns 503
   outside the challenge path until TLS is ready.
3. Request the certificate only after HTTP routing is verified:

   ```sh
   sudo /home/gw/.local/bin/certbot certonly --webroot -w /var/www/certbot -d nostr.gwhyyy.com
   ```

   Use the secure interactive prompt for account/email/terms if required. Do not
   borrow an unrelated certificate or disable TLS checks. If Cloudflare blocks
   the challenge, inspect the domain-specific rule before proposing changes.
4. Atomically point `/var/www/nostr/current` to the completed release. Replace the
   host's bootstrap config with `ops/nginx/nostr.conf`. Check the referenced
   certificate/options paths exist, run `sudo nginx -t`, then separately reload.
5. Verify origin TLS with SNI and public Cloudflare HTTPS. Confirm this site's
   title, not merely HTTP 200. Check `/`, `/docs/`, a deep guide, `/playground/`,
   Flutter JS/WASM assets, `/robots.txt`, `/sitemap.xml`, `/llms.txt`, social card,
   and an unknown URL returning **404**, plus HTTP → HTTPS. Inspect both browser
   consoles and the actual relay read workflow. Do not publish a public event
   without explicit approval.
6. Certbot timer is present, but renewal for this new certificate must be
   verified with a scoped `certbot renew --cert-name nostr.gwhyyy.com --dry-run`.
   Arrange an nginx reload deploy hook after renewal; test it with administrator
   approval. Do not claim renewal works merely because the timer exists.

## Rollback

Keep the previous release and vhost backup. Restore the previous `current` target
atomically; test nginx before reloading if configuration changed. For a failed
first deployment, disable only the new nostr vhost and restore its prior absence.
Do not delete certificates, other sites, release history, or the old Pages branch.

## GitHub Pages

Existing `gh-pages` deployment remains untouched. The Actions build explicitly sets
`SITE_URL=https://anasfik.github.io` and `BASE_URL=/nostr/`; it is not the production
domain release pipeline. Actions billing was previously locked. Domain-root links
and the Flutter `/playground/` build target are for the custom domain; do not deploy
this assembled domain build onto a repository-path Pages site. A future Pages
migration needs redirect mapping for old deep links, not a blind artifact copy.
