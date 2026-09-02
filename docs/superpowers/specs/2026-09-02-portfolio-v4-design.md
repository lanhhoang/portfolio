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

- Visitors can browse projects, posts, profile information, a résumé, and a contact form on desktop and mobile.
- Visitors can search and filter published projects and posts.
- The owner can securely create, preview, publish, unpublish, and schedule projects and posts without editing Git files.
- The owner can manage profile content, résumé files, tags, images, and contact messages from `/admin`.
- Contact messages are saved before email delivery and remain recoverable if delivery fails.
- Draft and scheduled content cannot be accessed through public routes.
- The app deploys as one container to one small server, with durable local data and tested off-site backups.

## 3. Scope

### Public v1

- Homepage
- Projects index and detail pages
- Blog index and post pages
- Search and tag filtering for projects and posts
- About/profile page
- Résumé page and PDF download
- Contact form
- Responsive navigation
- SEO metadata, sitemap, and structured data

### Private v1

- Owner-only authentication with password and TOTP
- Dashboard summary
- Project management
- Post management
- Markdown editing and preview
- Draft, scheduled, and published states
- Image and résumé uploads
- Tag management
- Profile management
- Contact inbox with delivery state and retry

### Deferred

- RSS feed
- Email newsletter

### Explicit non-goals

- Public user accounts
- Multiple admins, roles, or permissions
- Comments
- Public API
- Separate frontend or headless CMS
- Git-backed content synchronization
- Page builder
- Revision history
- Media-library subsystem
- Dedicated search service
- Analytics or observability platform

## 4. Technical Architecture

Use the current stable releases of:

- Ruby on Rails
- Hotwire: Turbo and Stimulus
- Tailwind CSS
- SQLite

Rails serves both the public site and the `/admin` namespace. Pages are server-rendered. Turbo improves navigation and form updates; Stimulus is reserved for behavior that requires client-side interaction, such as Markdown preview and the mobile menu. There is no SPA layer and no internal JSON API.

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

- `/` — homepage
- `/projects` — published projects, search, and tag filters
- `/projects/:slug` — published project
- `/blog` — published posts, search, and tag filters
- `/blog/:slug` — published post
- `/about` — biography and experience
- `/resume` — résumé page
- `/resume/download` — current PDF
- `/contact` — contact form
- `/sitemap.xml` — public sitemap

The main navigation labels are **Work**, **Journal**, **About**, **Résumé**, and **Contact**. The site mark returns to the homepage.

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

### Project

- title
- unique slug
- summary
- body Markdown
- rendered, sanitized body HTML
- role
- start and end dates
- live URL and source URL
- featured position, nullable
- state: `draft`, `scheduled`, or `published`
- scheduled timestamp, nullable
- published timestamp, nullable
- timestamps
- one cover image and optional gallery images through Active Storage
- tags through Tagging

### Post

- title
- unique slug
- excerpt
- body Markdown
- rendered, sanitized body HTML
- state: `draft`, `scheduled`, or `published`
- scheduled timestamp, nullable
- published timestamp, nullable
- timestamps
- optional cover image through Active Storage
- tags through Tagging

### Tag and Tagging

Tags have a unique name and slug. Tagging associates a tag with either a project or post. Tags support public filters and admin organization.

### Profile

A single profile record stores:

- display name
- homepage headline
- short introduction
- biography Markdown and rendered HTML
- availability label
- public contact email
- social links
- portrait through Active Storage

### Resume

A single current résumé record stores a title, short description, updated date, and attached PDF.

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

Projects, posts, and biography content are authored in Markdown with an admin preview. On save, the server renders Markdown to HTML, disables raw HTML, sanitizes the result, and stores the rendered HTML. Technical code blocks are supported.

Public requests use the stored HTML rather than rendering Markdown on every request.

### Publication states

- **Draft:** visible only in authenticated admin views and previews.
- **Scheduled:** visible only to the admin until its scheduled timestamp.
- **Published:** visible publicly with a published timestamp.

Manual publication changes the state to `published` and records the publication time. Unpublishing returns content to `draft` without changing its slug.

A recurring Solid Queue task finds scheduled records whose scheduled time has passed and publishes them in a transaction. This scan is idempotent. If the server is unavailable at the scheduled time, the next run publishes overdue records.

### Search and filtering

Search uses parameterized SQLite queries over titles, summaries or excerpts, and Markdown bodies. Tag filters use normal Active Record joins. Results include published records only and are ordered by publication date.

The expected content volume does not justify FTS, Elasticsearch, or another search service. SQLite FTS can replace the query later if measured relevance or performance becomes inadequate.

## 8. Public Experience

### Visual direction

The approved direction is **Bold Minimal**:

- near-black primary background
- warm off-white text
- one restrained acid-green accent
- oversized geometric headlines
- compact uppercase labels
- strong grid alignment
- flat surfaces without gradients or decorative shadows
- sparse motion limited to useful hover, focus, menu, and Turbo transition feedback

The design must maintain readable line lengths, visible focus states, sufficient contrast, and reduced-motion support.

### Homepage hierarchy

1. Compact header with site mark, navigation, and availability state
2. Large three-line positioning statement: “Ideas. Interfaces. Impact.”
3. Short personal introduction
4. Selected projects in an asymmetric grid
5. Recent writing as a compact editorial list
6. Contact prompt and footer links

### Other public pages

- **Work:** searchable and tag-filterable project index, followed by focused case-study pages.
- **Journal:** searchable and tag-filterable post index, followed by reading-first article pages.
- **About:** biography, experience, skills, and external profiles.
- **Résumé:** readable summary with a direct PDF download.
- **Contact:** short form with explicit submission, validation, and delivery feedback.

On small screens, navigation collapses to an accessible menu, grids become a single reading column, and display type scales down without producing narrow multi-line fragments.

## 9. Admin Experience

The admin uses a restrained utility layout rather than reproducing the public site's display typography.

### Dashboard

Show only actionable summaries:

- draft content
- upcoming scheduled publications
- unread contact messages
- failed email deliveries

### Editors

Project and post forms provide:

- validated metadata fields
- Markdown textarea
- rendered preview
- image uploads
- tag selection
- explicit **Save draft**, **Schedule**, and **Publish** actions

Destructive actions require confirmation. Validation errors preserve entered content. Slugs are generated from titles but remain editable and stable after publication.

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

A nightly host task:

1. Uses SQLite's online backup command to create a consistent primary-database snapshot.
2. Runs an encrypted backup of that snapshot and Active Storage uploads to S3-compatible storage.
3. Retains daily and weekly restore points.
4. Reports backup failure through the configured operational email channel.

The repository includes a documented restore command. A restore test is required before launch and after any backup-process change.

### Operations

- Rails health endpoint for external uptime checks
- Structured logs to standard output
- Secrets managed outside Git
- Dependency and OS security updates applied regularly
- No Redis, CDN, Kubernetes, or centralized observability service in v1

## 14. Testing Strategy

Use Rails' default test stack. Add the smallest tests that protect private access, publication state, and visitor data.

### Model and job tests

- publication-state validation and transitions
- scheduled publication, including overdue catch-up and idempotency
- Markdown rendering and sanitization
- slug uniqueness
- upload restrictions
- contact email success and failure state

### Request and authorization tests

- drafts and scheduled records return 404 publicly
- published records are accessible
- unauthenticated requests cannot access admin or preview routes
- password and TOTP steps are both required
- contact throttling and validation
- search and tag filters never expose unpublished content

### System tests

- owner signs in, creates a draft, previews it, and publishes it
- visitor submits a contact message; owner sees it in the inbox

### Presentation checks

- responsive layouts at small-phone, tablet, laptop, and wide-desktop widths
- keyboard navigation and visible focus
- color contrast and reduced motion
- valid titles, descriptions, canonical URLs, Open Graph data, sitemap, and structured data
- responsive image sizing and absence of unnecessary client JavaScript

Caching is added only after production measurements show a need.

## 15. Release Boundary

Launch requires:

- all public and admin v1 flows working
- owner authentication and recovery verified
- SMTP delivery verified in production
- scheduled publishing verified
- backup and restore tested
- accessibility and responsive checks completed
- initial profile, résumé, at least one project, and at least one post loaded

RSS and newsletter work begin only after the core portfolio is live and stable.

## 16. Decision Summary

Rails is preferred over Astro or Hugo because the private dashboard, database-backed content, uploads, email, authentication, and scheduling are first-class requirements. A static frontend would require a second CMS or custom application and a content rebuild pipeline.

Laravel with Livewire and Filament is a credible alternative, particularly for rapid admin construction, but Rails better matches the selected preference for a cohesive application while keeping the same server-rendered interaction model and compact deployment.

The chosen design deliberately uses native Rails facilities and SQLite until real scale or operational evidence requires more infrastructure.

## References

- [marcoroth.dev](https://marcoroth.dev/)
- [Ruby on Rails 8.0 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Rails Active Job Basics](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails Active Storage Overview](https://guides.rubyonrails.org/active_storage_overview.html)
- [Securing Rails Applications](https://guides.rubyonrails.org/security.html)
- [Astro CMS integrations](https://docs.astro.build/en/guides/cms/)
- [Filament admin panels](https://filamentphp.com/docs/5.x/introduction/overview)
