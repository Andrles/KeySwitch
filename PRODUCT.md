# KeySwitch

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS desktop application (Swift + AppKit), macOS 13+, Apple Silicon and Intel. The Impeccable platform enum in this skill version does not include macOS; do not misclassify this application as web or iOS.

## Product Purpose

Current product: correct Russian/English keyboard-layout mistakes locally on a Mac.

Confirmed current scope, 2026-10-03: improve the macOS keyboard utility first. Voice, AI and other operating systems are deferred global additions in ROADMAP.md, excluded from this implementation. The earlier Keyray-like direction remains a future reference, not the current release requirement.

## Users

Current usage scenario evidenced by README: people typing Russian and English in macOS applications. The primary commercial audience and its priority workflows remain undecided.

## Operating Context

Menu-bar utility with a settings window. Global keyboard events and synthetic replacement require macOS Accessibility permission. Corrections run after word boundaries; double Shift forces conversion of the current buffered word. Applications can be excluded.

## Capabilities and Constraints

Implemented in 3.2.0 (local package verified; validation limits documented below): guarded selected-text layout/case editing, configurable manual commands, learned vocabulary and explicit correction pairs with JSON transfer, RU/EN conversion, system offline dictionaries and built-in names, spelling modes, ignored words, application exclusions, launch at login, appearance selection, optional GitHub release checks.

Not implemented in this repository: voice capture and transcription, AI providers and prompt workflows, translation, dictionary synchronization, Windows/Linux integrations, licensing/billing, a marketing website.

Existing input monitoring, UI, dictionaries, input-source selection and login integration use macOS APIs. Cross-platform architecture and voice/AI provider choices remain open decisions.

## Brand Commitments

Existing name: KeySwitch. User-supplied product reference: https://www.keyray.ru. Reference establishes desired product breadth; no visual-copy requirement was confirmed.

## Evidence on Hand

Current comparative audit: COMPARISON_AUDIT_2026-10-04.md (3.1.1 baseline).
Current implementation and validation status: IMPLEMENTATION_3.2.0.md.

README.md, README.en.md, PRIVACY.md, CHANGELOG.md, docs/KNOWN_ISSUES.md; Swift sources, deterministic stress corpus and installation fixtures. Native light-theme screenshots were inspected; live keyboard integration requires explicit access for the test build. Component tests and UI preview do not establish editor compatibility.

## Open Decisions

- Primary audience and first commercial use cases.
- Voice MVP scope, model, hardware requirements and licensing.
- AI local/cloud boundary, explicit sending consent, credentials storage and providers.
- Order of Windows and Linux delivery; Linux display-server scope.
- Feature parity target, monetization and distribution/signing strategy.
- Architecture for shared logic and native platform adapters.

Current privacy documentation promises no transmission of typed text and no saved typing history. Future cloud AI functionality requires an explicit change to that product contract before release.
