# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary: **hiring managers and recruiters** evaluating the owner for a product engineering role. They often arrive cold from a link in an application, LinkedIn or GitHub. They skim on desktop or phone and must decide within seconds whether the owner is worth an interview. They need four answers fast: who this is, what role, at what level, and proof.

Secondary: developer peers reading the technical blog. Their needs are a reading experience and links to source code.

The owner (single admin) manages all content through `/admin`. That surface is mobile-first, English-only and Operate-mode, and it is out of scope for public design decisions.

## Product Purpose

A personal portfolio, technical blog and résumé for one **product engineer**: someone who owns features end to end, from problem to shipped outcome, with design awareness. Success means a hiring visitor leaves with a clear sense of the owner's role, level and impact, and takes one action: reads a case study, downloads the résumé, or sends a message.

## Positioning

A product engineer who works across **English, French and Vietnamese**. The three languages are central to the owner's story, not just a reach feature. Every public page and every piece of authored content is published per language, and nothing falls back silently to the wrong language. The trilingual capability should be presented as part of who the owner is, not hidden as a utility switch.

## Operating Context

- Visitors arrive at locale-prefixed routes (`/en`, `/fr`, `/vi`). Each translation is published independently, so content can exist in one language and not yet in another.
- The public pages are: home, projects (index and detail), blog (index and post), about, résumé (page and localized PDF download), and contact form.
- The site follows the visitor's system light/dark preference, and visitors can save an override. The owner picks one accent from fixed presets: brown, green, lime, orange or yellow.

## Capabilities and Constraints

- Rails 8.1 monolith, server-rendered with Hotwire (Turbo plus Stimulus only where behaviour requires it) and Tailwind CSS v4. There is no SPA layer and no JSON API.
- All public content comes from the CMS: profile (display name, headline, introduction, availability label, biography, portrait, social links), projects (role, dates, featured position, live and source URLs, cover and gallery images, Markdown body), posts, tags and résumé. Designs must work with whatever the owner authors and must not hard-code the owner's copy.
- Locale-aware search and tag filtering exist for projects and posts.
- Contact messages are saved before email delivery is attempted.
- Deploys as one container on one small server. No analytics, comments, public accounts or newsletter.
- **Open:** exact job title wording, seniority, location and remote preference, and target role type. The owner supplies these through the profile content, not the design.

## Brand Commitments

- The original spec asks for a bold, minimal, modern feel that is easy to navigate. It draws on marcoroth.dev (large type, sparse navigation, direct personal presentation) but must not copy its layout or identity.
- Be Vietnam Pro is the committed typeface, and it must render Vietnamese and French diacritics correctly.
- The fixed accent presets are brown, green, lime, orange and yellow.

## Evidence on Hand

Confirmed as real and shareable (to be authored in the CMS):

- client or employer work with outcomes or metrics
- open-source and side projects with public repos or live demos
- technical writing
- a professional portrait and a localized résumé PDF.

The current development database holds only demo seed data ("Demo Designer", "Sample System", 1×1 placeholder images). Do not treat it as real content. Never invent metrics, clients, employers, testimonials or outcomes.

## Product Principles

1. **Identity before ornament.** Within seconds, a visitor knows who this is, what role they do, at what level, and where to find proof.
2. **Proof over claims.** Lead with case studies that show problem, role and outcome, not adjectives.
3. **Three languages are a first-class trait.** Treat translation as part of the owner's identity, never as a hidden utility. Never fall back silently to another language.
4. **One clear next step.** Every page leads to a case study, the résumé or contact.
5. **Content-driven resilience.** Layouts hold up with long French and Vietnamese strings, missing translations, few items or many.

## Accessibility & Inclusion

Already established and to be preserved:

- WCAG AA contrast in both themes and with every accent preset.
- Full keyboard use with visible focus.
- Respect for reduced-motion preferences.
- Usable at a 320px viewport width and at 200% browser zoom.
- Correct `lang` and `hreflang` attributes per locale.
