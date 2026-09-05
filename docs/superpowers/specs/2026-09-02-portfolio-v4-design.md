# Portfolio v4 Design

**Date:** 2026-09-02  
**Status:** Approved design  
**Architecture:** Rails monolith

## 1. Purpose

Portfolio v4 is a personal website with two surfaces:

1. A public portfolio and technical blog.
2. A private, single-owner admin dashboard for managing all public content and contact messages.

The product should feel bold, minimal, modern, and easy to navigate. Its visual foundation takes cues from [marcoroth.dev](https://marcoroth.dev/)—large typography, sparse navigation, and direct personal presentation—without copying its layout or identity.

The primary technical goal is one cohesive application with the fewest operational dependencies.

## 2. Success Criteria

The first release is successful when:

- Visitors can use every public and admin flow from a phone, with layouts progressively enhanced for desktop and large screens.
- Public navigation and content support English, French, and Vietnamese without silently falling back to the wrong language.
- Visitors can search and filter published projects and posts within the active language.
- The interface follows the visitor's light/dark system preference, supports a saved override, and uses the owner-selected accent preset.
- The owner can securely create, translate, preview, publish, unpublish, and schedule projects and posts without editing Git files.
- The owner can manage profile content, localized résumé files, tags, images, theme accent, and contact messages from `/admin`.
- Contact messages are saved before email delivery and remain recoverable if delivery fails.
- Draft and scheduled translations cannot be accessed through public routes.
- The app deploys as one container to one small server, with the application database and every uploaded asset covered by tested off-site backups.

## 3. Scope

### Public v1

- Localized English, French, and Vietnamese routes and interface text
- Homepage
- Projects index and detail pages
- Blog index and post pages
- Locale-aware search and tag filtering for projects and posts
- About/profile page
- Localized résumé page and PDF download
- Contact form
- Mobile-first responsive layout, navigation, and language switcher
- System-aware light and dark themes with a saved visitor override
- One owner-selected accent from Brown, Green, Lime, Orange, and Yellow
- SEO metadata, canonical URLs, `hreflang`, sitemap, and structured data

### Private v1

- Owner-only authentication with password and TOTP
- English-language, mobile-first responsive dashboard UI
- Project and translation management
- Post and translation management
- Markdown editing and preview per locale
- Draft, scheduled, and published states per translation
- Image and localized résumé uploads
- Localized tag and profile management
- Site accent selection from fixed presets
- Contact inbox with delivery state and retry

### Deferred

- RSS feed
- Email newsletter

### Explicit non-goals

- Public user accounts
- Multiple admins, roles, or permissions
- Machine translation
- Translated admin interface
- Comments
- Public API
- Separate frontend or headless CMS
- Git-backed content synchronization
- Page builder
- Revision history
- Media-library subsystem
- Dedicated search service
- Visitor-defined or arbitrary accent colors
- Analytics or observability platform

## 4. Technical Architecture

Use the current stable releases of:

- Ruby on Rails
- Hotwire: Turbo and Stimulus
- Tailwind CSS
- SQLite

Rails serves both the public site and the `/admin` namespace. Pages are server-rendered. Rails I18n translates interface copy, while normalized translation records store authored public content. Turbo improves navigation and form updates; Stimulus is reserved for behavior that requires client-side interaction, such as Markdown preview and the mobile menu. Native CSS custom properties provide theme and accent tokens. There is no SPA layer and no internal JSON API.

### Rails facilities

- **Active Record:** application data
- **Active Storage:** project images, post images, portrait, and résumé PDF
- **Action Mailer:** contact notifications
- **Active Job + Solid Queue:** email delivery and scheduled publishing
- **Puma:** web server and, on this single-server deployment, the Solid Queue supervisor

SQLite stores primary application data and Solid Queue jobs. Active Storage uses the local disk service. Database files and uploads live under one mounted data directory.

### External dependencies

Only two external services are required:

1. An SMTP-compatible transactional email provider.
2. S3-compatible object storage for encrypted off-site backups.

Neither service participates in normal page rendering.

## 5. Routes and Navigation

### Public routes

All public pages use an explicit locale prefix limited to `en`, `fr`, or `vi`:

- `/:locale` — localized homepage
- `/:locale/projects` — published project translations, search, and tag filters
- `/:locale/projects/:slug` — published project translation
- `/:locale/blog` — published post translations, search, and tag filters
- `/:locale/blog/:slug` — published post translation
- `/:locale/about` — localized biography and experience
- `/:locale/resume` — localized résumé page
- `/:locale/resume/download` — current localized PDF
- `/:locale/contact` — localized contact form
- `/sitemap.xml` — sitemap containing every published locale URL

`/` redirects to the saved locale preference, then a supported browser language, then `/en`. Unsupported locale segments return 404 rather than being treated as content slugs.

The localized main navigation labels are **Work**, **Journal**, **About**, **Résumé**, and **Contact**. The site mark returns to the active locale's homepage. The language switcher preserves the equivalent page when that translation exists.

### Admin routes

All admin routes live under `/admin` and require an authenticated owner session plus completed TOTP verification.

- `/admin` — dashboard
- `/admin/projects`
- `/admin/posts`
- `/admin/tags`
- `/admin/profile`
- `/admin/resume`
- `/admin/messages`

Preview routes also require an admin session. v1 does not provide shareable public preview links.

## 6. Content Model

### AdminUser

- email
- password digest
- encrypted TOTP secret
- digested recovery codes
- timestamps

Only one owner account is supported. There is no registration route. A deployment task creates or resets the owner account.

### Project and ProjectTranslation

Project stores shared fields:

- role
- start and end dates
- live URL and source URL
- featured position, nullable
- timestamps
- one cover image and optional gallery images through Active Storage
- tags through Tagging

Each ProjectTranslation stores:

- project and locale, unique as a pair
- title
- slug, unique within its locale
- summary
- body Markdown
- rendered, sanitized body HTML
- state: `draft`, `scheduled`, or `published`
- scheduled timestamp, nullable
- published timestamp, nullable
- timestamps

Every project requires an English translation. French and Vietnamese translations are optional and publish independently.

### Post and PostTranslation

Post stores shared timestamps, tags, and an optional cover image through Active Storage. Each PostTranslation stores:

- post and locale, unique as a pair
- title
- slug, unique within its locale
- excerpt
- body Markdown
- rendered, sanitized body HTML
- state: `draft`, `scheduled`, or `published`
- scheduled timestamp, nullable
- published timestamp, nullable
- timestamps

Every post requires an English translation. French and Vietnamese translations are optional and publish independently.

### Tag, TagTranslation, and Tagging

Tagging associates a tag with either a project or post. Each TagTranslation stores a locale-specific name and slug, unique within that locale. Tags support locale-aware public filters and admin organization. English is required; untranslated optional tags are omitted from that locale's filters.

### Profile and ProfileTranslation

The single Profile stores shared data:

- public contact email
- social links
- portrait through Active Storage
- accent preset: `brown`, `green`, `lime`, `orange`, or `yellow`; default `lime`

Each ProfileTranslation stores the locale-specific display name, homepage headline, short introduction, biography Markdown and rendered HTML, and availability label. English is required; French and Vietnamese are optional.

### Resume and ResumeTranslation

The single current Resume stores its updated date. Each ResumeTranslation stores a locale-specific title, short description, and attached PDF. English is required; French and Vietnamese are optional.

### ContactMessage

- sender name
- sender email
- subject
- message body
- state: `unread`, `read`, or `archived`
- email delivery state: `pending`, `delivered`, or `failed`
- delivered timestamp, nullable
- last delivery error, nullable
- timestamps

## 7. Publishing and Rendering

### Markdown

Project translations, post translations, and localized biographies are authored in Markdown with an admin preview. On save, the server renders Markdown to HTML, disables raw HTML, sanitizes the result, and stores the rendered HTML. Technical code blocks are supported.

Public requests use the stored HTML rather than rendering Markdown on every request.

### Publication states

Publication state belongs to each ProjectTranslation and PostTranslation:

- **Draft:** visible only in authenticated admin views and previews.
- **Scheduled:** visible only to the admin until its scheduled timestamp.
- **Published:** visible publicly within its locale with a published timestamp.

Manual publication changes that translation to `published` and records the publication time. Unpublishing returns it to `draft` without changing its slug. English must be published before another locale for the same record can be published.

A recurring Solid Queue task finds scheduled translations whose scheduled time has passed and publishes them in a transaction. This scan is idempotent. If the server is unavailable at the scheduled time, the next run publishes overdue translations.

The scheduling control uses the owner's browser-local time. JavaScript converts the selected wall time to an ISO 8601 instant before submission and rejects nonexistent daylight-saving times; repeated fall-back-hour times use the browser's earlier occurrence. Without JavaScript, the control is explicitly labeled and interpreted as UTC. Persisted timestamps remain UTC, while admin schedule summaries progressively render in browser-local time with UTC text as the fallback.

### Localization behavior

Rails I18n YAML files provide English, French, and Vietnamese navigation, forms, validation messages, date formats, and other fixed interface copy. The admin interface remains English.

The root route chooses a locale from the visitor's saved preference, then `Accept-Language`, then English. Public responses emit canonical and `hreflang` links for published translations only. On detail pages, the language switcher links available translations and marks missing translations unavailable; it never serves English content under a French or Vietnamese URL.

### Search and filtering

Search uses parameterized SQLite queries over titles, summaries or excerpts, and Markdown bodies in the active locale. Tag filters use normal Active Record joins and localized tag slugs. Results include published translations only and are ordered by publication date.

The expected content volume does not justify FTS, Elasticsearch, or another search service. SQLite FTS can replace the query later if measured relevance or performance becomes inadequate.

## 8. Public Experience

### Visual direction

The approved direction is **Bold Minimal** in both light and dark modes:

- dark background `#0D0D0D` with warm off-white text `#F4F1E8`
- light background `#F3F0E8` with near-black text `#151512`
- oversized geometric headlines
- compact uppercase labels
- strong grid alignment
- flat surfaces without gradients or decorative shadows
- sparse motion limited to useful hover, focus, menu, and Turbo transition feedback

Theme colors are semantic CSS custom properties rather than values scattered through components. The initial mode follows `prefers-color-scheme`; a manual light/dark override is stored locally. A tiny head script applies a saved override before paint to avoid a theme flash. The toggle remains keyboard accessible and exposes its current state.

The owner selects one global accent preset in admin. Lime is the default. Each preset has a brighter dark-mode value and a darker light-mode value so text and controls retain sufficient contrast:

| Preset | Dark mode | Light mode |
| ------ | --------- | ---------- |
| Brown  | `#C58A63` | `#7A4E35`  |
| Green  | `#5BC98B` | `#216E46`  |
| Lime   | `#BAFF54` | `#5A7600`  |
| Orange | `#FF8A3D` | `#A94300`  |
| Yellow | `#FFD84D` | `#806100`  |

Accent-filled controls use a dedicated contrasting foreground token. The design must maintain readable line lengths, visible focus states, WCAG AA contrast, and reduced-motion support in every theme/accent combination.

### Mobile-first layout rules

Base CSS targets narrow screens, touch input, single-column reading flow, and compact assets. Features are then added through content-driven `min-width` breakpoints:

- navigation expands from an accessible menu to a persistent header
- project and content grids gain columns only when each item remains readable
- typography scales without creating narrow multi-line fragments
- media requests use responsive image widths appropriate to the viewport
- interactive controls do not depend on hover and provide comfortable touch targets
- content uses maximum widths on large screens instead of stretching edge-to-edge

Phone layouts must not overflow horizontally at supported zoom levels. Desktop and large-screen layouts add hierarchy, whitespace, and density without changing content order or hiding functionality.

### Homepage hierarchy

1. Compact header with site mark, navigation, and availability state
2. Large three-line positioning statement: “Ideas. Interfaces. Impact.”
3. Short personal introduction
4. Selected projects in an asymmetric grid
5. Recent writing as a compact editorial list
6. Contact prompt and footer links

### Other public pages

- **Work:** locale-aware searchable and tag-filterable project index, followed by focused case-study pages.
- **Journal:** locale-aware searchable and tag-filterable post index, followed by reading-first article pages.
- **About:** localized biography, experience, skills, and external profiles.
- **Résumé:** localized summary with a direct locale-specific PDF download.
- **Contact:** localized short form with explicit submission, validation, and delivery feedback.

A compact language switcher is present throughout the public site. The mobile content order remains the source order so keyboard, screen-reader, and visual navigation stay aligned at every breakpoint.

## 9. Admin Experience

The admin uses a restrained utility layout rather than reproducing the public site's display typography. It is mobile-first: forms stack by default, primary actions remain reachable by touch, and wide data tables become labeled record rows or cards before columns become unreadable. Larger screens progressively add side navigation, columns, and denser tables without introducing desktop-only actions.

### Dashboard

Show only actionable summaries:

- draft content
- upcoming scheduled publications
- unread contact messages
- failed email deliveries

### Editors

Project and post forms separate shared metadata from English, French, and Vietnamese translation tabs. They provide:

- per-locale completion and publication indicators
- validated metadata fields
- Markdown textarea and rendered preview per locale
- shared image uploads
- localized tag selection
- independent **Save draft**, **Schedule**, and **Publish** actions per translation

Profile and résumé editors use the same locale tabs. Site appearance provides only the five approved accent presets; visitors control light/dark mode themselves.

Destructive actions require confirmation. Validation errors preserve entered content. Localized slugs are generated from translated titles but remain editable and stable after publication.

### Inbox

The inbox supports read, unread, archive, and retry-email actions. It is not a general-purpose CRM.

## 10. Contact Flow

1. The visitor submits the contact form.
2. Server-side validation, a honeypot, and rate limiting reject invalid or abusive requests.
3. Rails commits the ContactMessage with `pending` email state.
4. After commit, an Active Job sends the owner notification.
5. Success changes the delivery state to `delivered`.
6. Failure changes it to `failed`, records a safe error summary, and exposes a retry action in admin.
7. The public response confirms receipt once the message has been persisted; it does not claim that email delivery succeeded.

No message content is written to application logs.

## 11. Security

- No public registration or password-based API
- Password hashing through Rails' secure-password support
- TOTP second factor and one-time recovery codes
- Login and TOTP attempt throttling
- Password-reset tokens with expiration
- Session rotation after login and TOTP completion
- Secure, HTTP-only, same-site cookies in production
- Session expiration and explicit logout
- CSRF protection on all state-changing browser requests
- Authorization enforced by the admin base controller
- Generic login and password-reset responses to avoid account disclosure
- Content Security Policy and standard secure headers
- Markdown raw HTML disabled and rendered output sanitized
- Upload MIME type, extension, and size validation
- Contact rate limiting and honeypot
- Secrets supplied through encrypted credentials or deployment environment, never committed

CAPTCHA is deferred until observed spam shows that rate limiting and the honeypot are insufficient.

## 12. Error Handling

- Unknown or unpublished public slugs return the standard branded 404 page.
- Invalid forms return field-level errors without losing entered data.
- A failed contact email does not roll back or delete the saved message.
- Scheduled publishing can safely run more than once for the same record.
- Missing optional images render intentional text-first fallbacks.
- Admin job failures remain visible and retryable where owner action is useful.
- Public error pages do not expose exception details.

## 13. Deployment and Backups

### Runtime

Deploy the Rails image with Kamal to one small Ubuntu server. The reverse proxy terminates HTTPS. Puma serves requests and starts Solid Queue in-process for this single-server topology.

The persistent data directory contains:

- the primary SQLite database
- the Solid Queue SQLite database
- Active Storage uploads

Cache and transient runtime data do not require backup.

### Backup

The backup covers the primary SQLite application database—including content, translations, contact messages, and Active Storage metadata—and every Active Storage file, including images, portraits, and localized résumé PDFs.

A nightly host task:

1. Briefly pauses application writes.
2. Uses SQLite's online backup command to create a consistent primary-database snapshot and snapshots the Active Storage directory.
3. Resumes the application before network transfer begins.
4. Encrypts and uploads the snapshot to S3-compatible off-site storage.
5. Verifies checksums and reports failure through the configured operational email channel.
6. Retains 7 daily, 4 weekly, and 6 monthly restore points.

Solid Queue and cache databases are not restored. Publication schedules and contact delivery states live in the primary database, so recurring jobs can catch up or be retried; restoring stale queue rows could duplicate work.

The repository includes one documented restore command that recreates the persistent directory, verifies files, and runs SQLite integrity checks. The Rails decryption key and infrastructure credentials are kept separately in the owner's password manager. A restore test is required before launch, quarterly afterward, and after any backup-process change. The recovery targets are two hours of downtime and at most 24 hours of data loss.

### Operations

- Rails health endpoint for external uptime checks
- Structured logs to standard output
- Secrets managed outside Git
- Dependency and OS security updates applied regularly
- No Redis, CDN, Kubernetes, or centralized observability service in v1

## 14. Testing Strategy

Use Rails' default test stack. Add the smallest tests that protect private access, publication state, and visitor data.

### Model and job tests

- per-locale publication-state validation and transitions
- English-required and optional-translation rules
- scheduled translation publication, including overdue catch-up and idempotency
- localized slug uniqueness
- Markdown rendering and sanitization
- upload restrictions
- contact email success and failure state

### Request and authorization tests

- root locale selection and supported-locale constraints
- drafts, scheduled records, and missing translations return 404 publicly
- published translations are accessible only under their locale
- canonical and `hreflang` links include only published translations
- unauthenticated requests cannot access admin or preview routes
- password and TOTP steps are both required
- contact throttling and validation
- search and tag filters stay within the active locale and never expose unpublished content

### System tests

- owner signs in, creates English content, adds an optional translation, previews it, and publishes both independently
- visitor changes language and light/dark mode; both preferences persist
- owner changes the accent preset; public pages use the new semantic accent tokens
- visitor submits a contact message; owner sees it in the inbox

### Presentation and recovery checks

- public and admin layouts at phone portrait, phone landscape, tablet, laptop, desktop, and large-desktop widths
- no horizontal overflow at 320 CSS pixels or 200% browser zoom
- touch operation without hover-only actions
- keyboard navigation and visible focus
- WCAG AA contrast across both themes and all five accent presets
- reduced motion and no incorrect-theme flash on initial paint
- valid localized titles, descriptions, canonical URLs, Open Graph data, sitemap, `hreflang`, and structured data
- responsive image sizing and absence of unnecessary client JavaScript
- pre-launch and quarterly backup restore drills

Caching is added only after production measurements show a need.

## 15. Release Boundary

Launch requires:

- all public and admin v1 flows working
- owner authentication and recovery verified
- SMTP delivery verified in production
- scheduled publishing verified
- backup and restore tested for both SQLite data and Active Storage assets
- accessibility, theme, accent, locale, and responsive checks completed
- English profile, résumé, at least one project, and at least one post loaded
- French and Vietnamese interface translations complete; optional authored content may launch later

RSS and newsletter work begin only after the core portfolio is live and stable.

## 16. Decision Summary

Rails is preferred over Astro or Hugo because the private dashboard, database-backed content, uploads, email, authentication, and scheduling are first-class requirements. A static frontend would require a second CMS or custom application and a content rebuild pipeline.

Laravel with Livewire and Filament is a credible alternative, particularly for rapid admin construction, but Rails better matches the selected preference for a cohesive application while keeping the same server-rendered interaction model and compact deployment.

The chosen design deliberately uses native Rails facilities, normalized translation records, CSS custom properties, and SQLite until real scale or operational evidence requires more infrastructure. English content is required; French and Vietnamese authored translations are optional and publish independently. Light/dark mode follows the visitor's system by default, while the owner controls one site-wide accent from five fixed presets. Nightly encrypted off-site backups cover all irreplaceable database records and uploaded assets.

## References

- [marcoroth.dev](https://marcoroth.dev/)
- [Ruby on Rails 8.0 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Rails Active Job Basics](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails Active Storage Overview](https://guides.rubyonrails.org/active_storage_overview.html)
- [Rails Internationalization API](https://guides.rubyonrails.org/i18n.html)
- [Securing Rails Applications](https://guides.rubyonrails.org/security.html)
- [Astro CMS integrations](https://docs.astro.build/en/guides/cms/)
- [Filament admin panels](https://filamentphp.com/docs/5.x/introduction/overview)
