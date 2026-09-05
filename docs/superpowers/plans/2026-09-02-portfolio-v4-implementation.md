# Portfolio v4 Parent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a mobile-first, multilingual portfolio and owner-only CMS as one deployable Rails application, with each phase leaving a usable, testable result.

**Architecture:** One Rails monolith renders locale-scoped public pages and an English `/admin` interface. SQLite stores application and queue data, Active Storage owns uploads, Solid Queue handles asynchronous work, and native Rails/Hotwire facilities are preferred over additional dependencies.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.x, Hotwire, Tailwind CSS, SQLite, Active Storage, Solid Queue, Commonmarker, ROTP, Minitest, Capybara, Kamal, Restic

**Spec:** `docs/superpowers/specs/2026-09-02-portfolio-v4-design.md`

## Global Constraints

- Public locales are exactly `en`, `fr`, and `vi`; English authored content is required and other translations are optional.
- Public URLs use explicit locale prefixes; `/` redirects by locale cookie, supported `Accept-Language`, then `/en`.
- The admin interface is English and supports one owner only; there is no registration.
- Public and admin CSS is mobile-first; every action remains usable at 320 CSS pixels, 200% zoom, and without hover.
- Initial color mode follows `prefers-color-scheme`; a manual override is stored in `localStorage` and applied before paint.
- Accent presets are fixed to Brown, Green, Lime, Orange, and Yellow; Lime is the default.
- Markdown raw HTML stays disabled and rendered output is sanitized before persistence.
- Draft, scheduled, missing, and unpublished translations never leak through public routes, search, metadata, or sitemap.
- Contact messages commit before email delivery and remain retryable after delivery failure.
- Production remains one application container on one small Ubuntu server; do not add Redis, a separate API, SPA, CMS, search service, CDN, or observability platform.
- Primary SQLite data and every Active Storage asset receive encrypted off-site backups with 7 daily, 4 weekly, and 6 monthly restore points.
- Use Rails defaults and the standard library before adding dependencies. The only planned application gems beyond generated Rails defaults are `commonmarker` and `rotp`.
- Use Minitest and Capybara. Every behavior task follows red-green-refactor and ends with a focused test run and commit.

---

## Execution Rules

1. Execute phases in order. A later phase may consume only interfaces documented by earlier phases.
2. Complete the phase acceptance checks before starting the next phase.
3. Keep migrations forward-only after a phase is accepted; add corrective migrations instead of editing applied ones.
4. Use development seed data only for demonstrations and tests. Never commit personal production content or credentials.
5. Run `bin/rails test` at every phase boundary. Run `bin/rails test:system` from Phase 3 onward.
6. Do not fold later-phase scope into an earlier phase. Each phase must remain independently reviewable.
7. Detailed commands, code, and tests live in the phase documents below. This parent remains unchanged while phase plans are executed.

## Planned File Boundaries

| Area                  | Responsibility                                                              | Primary paths                                                                                                                                                              |
| --------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Application shell     | locale routing, theme bootstrap, navigation, mobile-first tokens            | `config/routes.rb`, `app/controllers/public_controller.rb`, `app/views/layouts/application.html.erb`, `app/assets/tailwind/application.css`, `app/javascript/controllers/` |
| Content domain        | shared records, locale records, Markdown rendering, publication rules       | `app/models/`, `db/migrate/`, `db/seeds.rb`                                                                                                                                |
| Public delivery       | homepage, projects, journal, about, résumé, search, locale switching        | `app/controllers/public/`, `app/views/public/`                                                                                                                             |
| Admin security        | password, TOTP, recovery, sessions, reset                                   | `app/controllers/admin/`, `app/models/admin_user.rb`, `app/models/admin_session.rb`, `lib/tasks/admin.rake`                                                                |
| Admin CMS             | dashboard, forms, previews, uploads, translation actions                    | `app/controllers/admin/`, `app/views/admin/`, `app/javascript/controllers/admin/`                                                                                          |
| Scheduling            | due-content scan and recurring Solid Queue configuration                    | `app/jobs/publish_due_translations_job.rb`, `config/recurring.yml`                                                                                                         |
| Contact               | persistence, anti-spam, mail, owner inbox and retries                       | `app/models/contact_message.rb`, `app/controllers/public/contact_messages_controller.rb`, `app/mailers/`, `app/jobs/`, `app/views/admin/messages/`                         |
| Discovery and quality | metadata, `hreflang`, sitemap, JSON-LD, accessibility and responsive checks | `app/helpers/metadata_helper.rb`, `app/controllers/sitemap_controller.rb`, `app/views/sitemap/`, `test/system/`                                                            |
| Operations            | container deployment, health, encrypted backup and restore                  | `Dockerfile`, `config/deploy.yml`, `bin/backup`, `bin/restore`, `docs/operations.md`                                                                                       |

## Phase Order

| Phase | Usable result                                                                                   | Complexity  | Detailed plan                                                          |
| ----- | ----------------------------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------- |
| 1     | Bootable localized Rails shell with mobile navigation, light/dark mode, and all accent presets  | Lowest      | `docs/superpowers/plans/portfolio-v4/phase-01-foundation.md`           |
| 2     | Database-backed public portfolio, journal, profile, résumé, locale search, filters, and uploads | Low–medium  | `docs/superpowers/plans/portfolio-v4/phase-02-public-content.md`       |
| 3     | Owner can securely sign in with password plus TOTP and recover/reset access                     | Medium      | `docs/superpowers/plans/portfolio-v4/phase-03-admin-authentication.md` |
| 4     | Owner can manage and preview all localized public content and assets from a mobile-first admin  | Medium–high | `docs/superpowers/plans/portfolio-v4/phase-04-admin-cms.md`            |
| 5     | Locale translations publish, unpublish, and schedule safely, including downtime catch-up        | High        | `docs/superpowers/plans/portfolio-v4/phase-05-publishing.md`           |
| 6     | Visitors can submit contact messages; owner receives email and manages/retries an inbox         | High        | `docs/superpowers/plans/portfolio-v4/phase-06-contact.md`              |
| 7     | Public release meets locale SEO, accessibility, responsive, theme, and error-page requirements  | High        | `docs/superpowers/plans/portfolio-v4/phase-07-release-quality.md`      |
| 8     | App deploys to one server and can back up and restore SQLite plus every uploaded asset          | Highest     | `docs/superpowers/plans/portfolio-v4/phase-08-operations.md`           |

---

## Phase 1 Contract: Rails Foundation and Responsive Shell

**Outcome:** A visitor can run the app, land in a supported locale, navigate every public shell route, switch languages, use the mobile menu, follow system light/dark mode, override it without a flash, and see any of the five server-selected accent presets.

**Included work:**

- Generate Rails with SQLite, Tailwind, Hotwire, and the default test stack.
- Configure `en`, `fr`, and `vi` I18n files and locale-scoped public routes.
- Implement root locale negotiation and a locale cookie.
- Build semantic application layout, mobile navigation, language switcher, theme bootstrap, theme controller, and semantic color tokens.
- Add smoke/system tests at phone and desktop sizes.

**Interfaces produced:**

- `PublicController#current_locale` and locale-preserving URL defaults.
- `ThemeHelper#theme_bootstrap_script` and `<html data-accent="...">` contract.
- I18n keys under `navigation.*`, `theme.*`, and `locales.*`.
- Shared public layout and responsive container classes consumed by every later public view.

**Acceptance:**

- `/` redirects deterministically to `/en`, `/fr`, or `/vi`.
- Unsupported locale paths return 404.
- Theme and locale choices survive navigation and reload.
- Navigation works by keyboard and touch at 320px without horizontal overflow.
- `bin/rails test && bin/rails test:system` passes.

---

## Phase 2 Contract: Public Content Domain

**Outcome:** The public site renders database-backed profile, résumé, projects, and posts in each available locale. Visitors can search and filter published content; unpublished or missing translations return 404.

**Included work:**

- Install Active Storage and add shared plus normalized translation tables.
- Add `commonmarker` and a single sanitized Markdown renderer.
- Implement publication scopes, locale-specific slug constraints, English-required validation, MIME/extension/size attachment validation, and tags restricted to projects/posts.
- Build public homepage, project, journal, about, and résumé controllers/views.
- Add locale-aware SQLite search and tag filtering.
- Add development seeds that demonstrate all record types without personal data.

**Interfaces produced:**

- `MarkdownRenderer.call(markdown) -> String`.
- `SearchText.normalize(value) -> String`, used for persisted Unicode case-folded search text and incoming queries.
- `ProjectTranslation.publicly_visible(locale:)` and `PostTranslation.publicly_visible(locale:)`.
- `ProjectTranslation.filtered(locale:, query:, tag_slug:)` and `PostTranslation.filtered(locale:, query:, tag_slug:)`.
- `Profile.current` and `Resume.current` singleton accessors.
- Active Storage attachment names fixed by the content model.

**Acceptance:**

- Each public page reads from SQLite and renders only the active locale.
- English is mandatory; French/Vietnamese records can be absent.
- Search escapes wildcard input, matches Unicode capitalization and normalization variants without removing accents, and never crosses locale/publication boundaries.
- Missing attachments have intentional text-first fallbacks.
- `bin/rails test` passes with model, request, and query coverage.

---

## Phase 3 Contract: Owner Authentication

**Outcome:** `/admin` is inaccessible without password and TOTP verification. The single owner can use a recovery code, reset a forgotten password, sign out, and recreate credentials through a non-interactive deployment task.

**Included work:**

- Add `AdminUser` and `AdminSession` with secure password support.
- Add `rotp`, encrypted TOTP secrets, one-use digested recovery codes, and enrollment output.
- Build password, TOTP, recovery-code, logout, and password-reset flows.
- Rotate sessions after authentication, expire them, and rate-limit attempts.
- Add the protected mobile-first admin layout and empty actionable dashboard.

**Interfaces produced:**

- `Current.admin_user` and `Admin::BaseController#require_admin!`.
- `AdminUser#verify_totp(code) -> Boolean`.
- `AdminUser#consume_recovery_code(code) -> Boolean`.
- `AdminSession` cookie token authentication.
- `bin/rails admin:create` environment contract.

**Acceptance:**

- Password alone never grants `/admin` access.
- TOTP replay, invalid recovery codes, expired sessions, and invalid reset tokens fail safely.
- Generic responses do not reveal whether the owner email exists.
- No registration route exists.
- Authentication request and system tests pass.

---

## Phase 4 Contract: Admin Content Management

**Outcome:** From phone or desktop, the owner can create and edit shared content, English/French/Vietnamese translations, tags, profile, résumé files, images, and the site accent; authenticated previews work without exposing drafts.

**Included work:**

- Build the admin dashboard and CRUD controllers/views for every content type.
- Use translation tabs with completion/publication indicators and stable localized slugs.
- Add shared image and locale-specific PDF upload controls with MIME type, filename extension, and size validation.
- Add a Turbo Frame Markdown preview endpoint.
- Add safe destructive confirmations and validation-preserving forms.
- Add accent selection limited to the five enum values.

**Interfaces produced:**

- Admin resource routes under `/admin` and authenticated preview routes.
- `Admin::MarkdownPreviewsController#create` returning sanitized preview HTML.
- Nested translation form parameter contracts for projects, posts, tags, profile, and résumé.
- Attachment validation methods and error messages reused by admin forms.

**Acceptance:**

- Complete CMS workflow works at 320px and desktop widths.
- Preview requires an authenticated owner and cannot be indexed.
- Upload violations and invalid translations preserve entered form data.
- Slugs remain stable unless explicitly edited.
- Admin request and system tests pass.

---

## Phase 5 Contract: Publishing and Scheduling

**Outcome:** The owner can publish, unpublish, and schedule each locale independently. Due translations publish exactly once, and overdue items catch up after downtime.

**Included work:**

- Centralize publication transitions for project and post translations.
- Add nested publication resources for project and post translations.
- Enforce English-first publication.
- Add idempotent `PublishDueTranslationsJob` and Solid Queue recurring configuration.
- Show drafts, upcoming schedules, and failed publication work on the dashboard.

**Interfaces produced:**

- `PublishableTranslation#publish`, `#schedule(at:)`, and `#unpublish`.
- `PublishableTranslation#publishable?` for the English-first guard.
- `PublishDueTranslationsJob.perform` scanning both translation models with no arguments.
- Dashboard queries for draft and scheduled translations.

**Acceptance:**

- Non-English publication fails until English is published.
- Re-running the due job does not change already published timestamps.
- Overdue schedules publish on the next scan.
- Public pages update without exposing other draft locales.
- Job, model, request, and system tests pass.

---

## Phase 6 Contract: Contact Delivery and Admin Inbox

**Outcome:** A visitor can submit a localized contact form. The message persists before delivery, the owner receives an email, and failed delivery remains visible and retryable in admin.

**Included work:**

- Add `ContactMessage` persistence and state constraints.
- Build localized public form with validation, honeypot, and rate limiting.
- Queue owner notification only after commit.
- Record delivery success/failure without logging message content.
- Build mobile-first inbox with read, unread, archive, and retry actions.

**Interfaces produced:**

- `ContactMessage#mark_delivered!` and `#mark_failed!(error)`.
- `ContactNotificationJob.perform(contact_message_id)`.
- `ContactMailer.owner_notification(contact_message)`.
- Admin message state and retry routes.

**Acceptance:**

- A persisted message receives a success response even if later email fails.
- Invalid/spam submissions do not enqueue mail.
- Delivery retries are idempotent and preserve the original message.
- Public logs never include the message body.
- Model, mailer, job, request, and system tests pass.

---

## Phase 7 Contract: Release Quality

**Outcome:** The public application is release-ready across supported locales, devices, themes, accents, accessibility modes, metadata consumers, and expected error paths.

**Included work:**

- Add localized title, description, canonical, Open Graph, `hreflang`, and JSON-LD helpers.
- Add `/sitemap.xml` containing published translations only.
- Add branded localized 404/422/500 pages with no exception details.
- Finish responsive image variants, keyboard/focus behavior, reduced motion, and contrast tokens.
- Add system coverage for locale, theme persistence, accent values, touch-sized navigation, zoom/overflow, and critical end-to-end flows.

**Interfaces produced:**

- `MetadataHelper#page_metadata` and `#alternate_locale_links`.
- `SitemapController#show` XML response.
- Stable semantic selectors used by system tests.

**Acceptance:**

- Metadata and sitemap contain no draft or missing translation URLs.
- Both themes and all accent pairs meet WCAG AA contrast targets from the spec.
- Public/admin critical paths work at phone portrait through large desktop.
- 320px and 200% zoom produce no horizontal page overflow.
- Full unit, request, and system test suites pass.

---

## Phase 8 Contract: Deployment, Backup, and Restore

**Outcome:** The accepted application deploys as one Rails container to one Ubuntu server, sends production mail, survives restarts, and has a proven encrypted restore path for primary SQLite data and all uploads.

**Included work:**

- Finalize production Docker image, Kamal configuration, secrets, TLS proxy, persistent bind mount, health checks, and Solid Queue-in-Puma.
- Add a host-side backup command that snapshots the primary database and Active Storage while writes are paused, resumes service, then transfers encrypted data with Restic.
- Retain 7 daily, 4 weekly, and 6 monthly snapshots and alert on failure.
- Add one guarded restore command with checksum and SQLite integrity verification.
- Document initial server setup, deploy, rollback, backup, restore, owner creation, and quarterly drills.

**Interfaces produced:**

- `/up` health endpoint.
- `/var/lib/portfolio/storage` persistent host contract.
- `bin/backup` and `bin/restore SNAPSHOT_ID` operator interfaces.
- Required deployment and backup environment variable list.

**Acceptance:**

- Kamal deploy and rollback complete without data loss.
- Restart preserves primary data and uploads.
- Backup excludes transient queue/cache databases and contains primary SQLite plus all blobs.
- A clean-server restore passes `PRAGMA integrity_check`, asset checksums, and application smoke tests.
- Recovery completes within two hours with a 24-hour maximum recovery point.

---

## Parent Completion Checklist

- [ ] Phase 1 accepted and tagged `portfolio-v4-phase-1`
- [ ] Phase 2 accepted and tagged `portfolio-v4-phase-2`
- [ ] Phase 3 accepted and tagged `portfolio-v4-phase-3`
- [ ] Phase 4 accepted and tagged `portfolio-v4-phase-4`
- [ ] Phase 5 accepted and tagged `portfolio-v4-phase-5`
- [ ] Phase 6 accepted and tagged `portfolio-v4-phase-6`
- [ ] Phase 7 accepted and tagged `portfolio-v4-phase-7`
- [ ] Phase 8 accepted and tagged `portfolio-v4-phase-8`

Do not mark a phase complete because its code exists. Mark it complete only after its acceptance commands pass and the usable result is manually demonstrated.
