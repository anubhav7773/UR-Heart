---
name: Desi Romantic Neo-Affordance
colors:
  surface: '#13131a'
  surface-dim: '#13131a'
  surface-bright: '#393840'
  surface-container-lowest: '#0d0e14'
  surface-container-low: '#1b1b22'
  surface-container: '#1f1f26'
  surface-container-high: '#292931'
  surface-container-highest: '#34343c'
  on-surface: '#e4e1eb'
  on-surface-variant: '#e5bdc0'
  inverse-surface: '#e4e1eb'
  inverse-on-surface: '#303037'
  outline: '#ac888a'
  outline-variant: '#5c3f42'
  surface-tint: '#ffb2ba'
  primary: '#ffb2ba'
  on-primary: '#67001f'
  primary-container: '#ff4f72'
  on-primary-container: '#5b001a'
  inverse-primary: '#bd0041'
  secondary: '#47f4f0'
  on-secondary: '#003736'
  secondary-container: '#00d7d4'
  on-secondary-container: '#005857'
  tertiary: '#edc157'
  on-tertiary: '#3f2e00'
  tertiary-container: '#b28b26'
  on-tertiary-container: '#372700'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffd9dc'
  primary-fixed-dim: '#ffb2ba'
  on-primary-fixed: '#400010'
  on-primary-fixed-variant: '#910030'
  secondary-fixed: '#50f9f6'
  secondary-fixed-dim: '#18ddd9'
  on-secondary-fixed: '#00201f'
  on-secondary-fixed-variant: '#00504e'
  tertiary-fixed: '#ffdf9b'
  tertiary-fixed-dim: '#edc157'
  on-tertiary-fixed: '#251a00'
  on-tertiary-fixed-variant: '#5b4300'
  background: '#13131a'
  on-background: '#e4e1eb'
  surface-variant: '#34343c'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.04em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system expresses a "Desi-Modern Romanticism" engineered for young adults (ages 18–32) navigating courtship, matrimony, and modern romance across Tier-2 and Tier-3 Indian cities. The visual language bridges emotional warmth with ironclad digital trust, acknowledging unique cultural imperatives around privacy, family discretion, and digital literacy.

The aesthetic fuses deep-night romance with vibrant, cyber-infused festive undertones:
- **Atmospheric Warmth meets Cyber Nightlife:** Contrast-rich dark surfaces evoke late-night terrace conversations, accented by high-voltage festival tones (crimson and electric turquoise) that signal passion and vibrancy without appearing westernized or impersonal.
- **High Affordance & Explicit Touch States:** Mitigates UX anxiety for first-time or cautious digital daters. Interactive zones never rely on subtle gestures alone; cards, badges, and action paths use bold tactile metaphors, visible boundaries, and generous padding.
- **Privacy as a Core Emotional Pillar:** Cultural contexts in emerging Indian metros demand visible reassurance. UI surfaces deliberately integrate "Shield & Trust" cues—watermarked profile layers, dynamic screenshots-disabled markers, and secure verification seals—treated as primary status badges rather than background utilities.

## Colors

The palette is tuned for high performance across a wide gamut of displays, ranging from budget IPS LCDs prone to backbleed to rich high-contrast AMOLED screens common in mid-tier smartphones.

### Surface Tiers
- **Canvas Base (`#0A0A0D`):** Deep near-black background preserving battery life on AMOLED while providing limitless contrast depth.
- **Surface Card (`#16161D`):** The primary interaction plane for swipeable profiles, chat containers, and feed modules.
- **Surface Raised (`#22222C`):** Higher elevation token for bottom sheets, quick replies, verification modals, and floating menu items.
- **Surface Border / Ghost Stroke (`#2E2E3C`):** 1px structural definition on dark surfaces to ensure crisp contrast on lower-end LCD panels.

### Brand & Accents
- **Primary Electric Crimson (`#FF2E63`):** High-passion callouts, primary matching actions, super-likes, and primary CTAs.
- **Secondary Cyber Turquoise (`#08D9D6`):** Discovery filters, active audio/video calling states, and mutual-interest indicators.
- **Accent Marigold Gold (`#FFD166`):** Gamified ad reward tokens, VIP badges, streaks, and auspicious horoscope affinity tags.

### Feedback & Privacy States
- **Status Danger (`#FF334B`):** Block, report, revoke access, and immediate disconnect actions.
- **Status Success (`#06D6A0`):** ID-verified profile badges, match confirmations, and secure vault locks.
- **Privacy Seal Tint (`rgba(8, 217, 214, 0.12)`): Translucent overlay used behind sensitive photo previews and discreet mode toggles.

### Typography Contrast
- **Text Primary (`#FFFFFF`):** Uncompromised legibility for bios, names, and CTAs.
- **Text Secondary (`#A0A0B2`):** Informational subtitles, timestamps, distances, and secondary prompts.
- **Text Muted (`#636375`):** Placeholders, disabled counters, and micro-captions.

## Typography

The typography system uses Inter as the Latin reference, paired at the layout engine level with Devanagari script system fonts (such as Hind or Noto Sans Devanagari) to maintain bilingual equilibrium.

### Script Integration Rules
- **Line Heights for Indic Scripts:** Devanagari glyphs with top shirorekha lines and low matras require 10–15% more vertical clearance than Latin forms. Line heights are explicitly padded across all body tokens (`body-lg` at 28px, `body-md` at 24px) to avoid diacritic clipping.
- **Hierarchy Stacking:** Profile headers place the prospective match's name in `headline-lg` or `headline-md`, accompanied by bilingual localized subtitles (e.g., profession, hometown) in `body-sm`.
- **Labels & Badging:** Privacy indicators and verification marks utilize `label-sm` with upper-case tracking to maintain crisp rendering at compact screen boundaries.

## Layout & Spacing

The layout is built for mobile ergonomics, optimizing for one-handed operation on tall modern aspect ratios (19.5:9 and 20:9).

### Grid and Canvas Metrics
- **Mobile Handset Canvas (Default):** Fluid single-column layout with fixed outer margins of `margin` (16px) and interior card gutters of `gutter` (16px).
- **Thumb Zone Anchor:** High-frequency actions (Pass, Like, Super-Like, Rewind, Chat trigger) are pinned within the bottom 25% screen container, floating over the canvas with explicit clearance from navigation bars.
- **Safe Boundary System:** Bottom sheets and full-screen modals enforce an additional 16px bottom padding to account for on-screen gesture bars and varied Android hardware wrappers.
- **Component Breathing Space:** Cards enforce internal padding of `space-lg` (24px) on key data sections, dropping to `space-md` (16px) inside compact sub-listings to sustain information density without visual crowding.

## Elevation & Depth

This system avoids soft, indistinct western neumorphism in favor of **Tonal Layering with Luminescent Accents and Hard Boundary Lines**, engineered to render reliably across low-cost hardware.

### Depth Hierarchy
1. **Level 0 (Canvas Base - `#0A0A0D`):** Background layer hosting full-bleed profile imagery and media backdrops.
2. **Level 1 (Surface Card - `#16161D`):** Main interactive profile cards, message threads, and feed items. Elevated using a 1px border stroke of `#2E2E3C` rather than pure blur shadows.
3. **Level 2 (Surface Raised - `#22222C`):** Overlays, sheets, floating pill action docks, and toast notifications. Employs an ambient, directional rim shadow: `0px 8px 24px rgba(0, 0, 0, 0.65)` complemented by a soft top stroke of `rgba(255, 255, 255, 0.08)`.
4. **Level 3 (Interactive Glowing Elements):** Action buttons (Electric Crimson and Cyber Turquoise) emit a directional ambient halo: `0px 4px 16px rgba(255, 46, 99, 0.35)` or `0px 4px 16px rgba(8, 217, 214, 0.35)` to signal active clickability.

### Privacy Veil Blur
When a profile activates anti-stalking or screenshot protection, underlying photos use a hardware-accelerated CSS/native blur (`backdrop-filter: blur(20px)`) topped with a recurring diagonal pattern and an explicit lock icon overlay.

## Shapes

The shape vocabulary prioritizes ultra-smooth, organic contours that reinforce intimacy, comfort, and tactile satisfaction.

### Corner Radii Architecture
- **Interactive Buttons & Badges (Pill - 999px):** All actionable buttons, interest tags, micro-tokens, and status chips apply a fully rounded pill form.
- **Profile Cards & Media Holders (24px):** Feed items, swiping photo canvases, and profile cards utilize a 24px radius, softening the presentation of full-screen photography.
- **Modals & Action Sheets (28px):** Bottom pull-up sheets and confirmation dialogs introduce a top-corner radius of 28px, visually embracing the user's thumb gestures.
- **Gamified Ad Badges & Reward Hubs (16px):** Compact rectangular modules with controlled rounded corners distinguish reward tokens and mini-quizzes from human discovery cards.

## Components

### Buttons & Interactive Controls
- **Touch Target Threshold:** All interactive controls enforce an absolute minimum touch zone of **48 × 48dp**, regardless of visual icon size.
- **Primary Action (Pill Shape, Height 52px):** Solid `#FF2E63` fill with bold white typography (`label-lg`), subtle top-edge highlight, and glowing shadow on hover/press.
- **Secondary Action (Pill Shape, Height 52px):** Outline variant with 2px stroke in `#08D9D6`, transparent background, and `#08D9D6` text. Pressing activates a 15% turquoise fill.
- **Icon Action Buttons (Floating Circle, 56 × 56px):** Elevated surface `#22222C` with high-contrast centered SVG glyphs for Rewind (Gold), Pass (Danger), and Match (Primary).

### Privacy Reassurance Badges
- **FLAG_SECURE Indicator:** Visual chip affixed to sensitive screen tops: deep `#16161D` fill, 1px border `#06D6A0`, displaying a verified shield icon with label "Screenshots Blocked / स्क्रीनशॉट सुरक्षित".
- **Discreet Family Mode:** Floating indicator showing an eye-slash glyph with immediate tap-to-minimize affordance.

### Gamified Ad Reward Tokens
- **Reward Credit Module:** Pill container with `#FFD166` border and warm gold gradient fill (`rgba(255, 209, 102, 0.12)`). Houses a coin icon, bold point balance (`label-md`), and a pulsing "Watch & Unlock" trigger with explicit progress counters.

### Chips & Interest Tags
- **Selection Chips:** Height 36px, radius 999px. Unselected state uses `#16161D` with `#A0A0B2` text. Selected state switches to `#22222C` with a 1.5px `#FF2E63` border and white text.

### Form Inputs & Text Fields
- **Container Specs:** Height 56px, radius 16px, background `#16161D`, border 1.5px `#2E2E3C`.
- **Focus State:** Border shifts dynamically to `#08D9D6` with a soft outer glow; floating label transitions in `#08D9D6`.
- **Input Aids:** Large text entry (16px minimum to avoid iOS/Android automatic viewport zooming) accompanied by clear bilingual helper strings.

### Cards & Discovery Containers
- **Main Swiping Card:** 24px border radius, anchored image container with a bottom-to-top gradient (`linear-gradient(180deg, transparent 60%, rgba(10, 10, 13, 0.95) 100%)`) ensuring all white headline text over photos exceeds WCAG AAA contrast ratios.