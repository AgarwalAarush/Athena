# Theme System Documentation

A comprehensive design system for Athena featuring liquid glass aesthetics and modular components.

---

## Architecture Overview

The Theme system is organized into distinct layers:

```
Theme/
├── Materials.swift       # Glass effects and vibrancy materials
├── Colors.swift          # Semantic color palette
├── Metrics.swift         # Spacing, sizing, and layout constants
├── Animations.swift      # Animation timing and easing curves
└── Components/
    ├── Button/
    │   ├── HoverIconButton.swift    # Icon-only buttons with hover effects
    │   └── GlassButton.swift        # Full buttons with glass styling
    └── GlassCard.swift              # Container components
```

---

## Core Concepts

### 1. Liquid Glass Materials

Glass materials provide the signature frosted, translucent appearance:

```swift
// Primary glass for main containers
.background(AppMaterial.primaryGlass)

// Secondary glass for nested elements
.background(AppMaterial.secondaryGlass)

// Tertiary glass for subtle overlays
.background(AppMaterial.tertiaryGlass)
```

Use the `.glassBackground()` modifier for convenience:

```swift
Text("Content")
    .glassBackground(
        material: AppMaterial.primaryGlass,
        cornerRadius: AppMetrics.cornerRadiusLarge
    )
```

### 2. Semantic Colors

Colors are defined semantically, not literally:

```swift
// Use semantic names
AppColors.primary          // Primary content
AppColors.secondary        // Secondary content
AppColors.accent          // Interactive elements

// Interaction states
AppColors.hoverOverlay    // Hover feedback
AppColors.activeOverlay   // Press feedback
AppColors.selectionOverlay // Selection state

// Status colors
AppColors.error           // Red
AppColors.warning         // Orange
AppColors.success         // Green
AppColors.info           // Blue
```

### 3. Consistent Metrics

All spacing, sizing, and dimensions use centralized constants:

```swift
// Corner radii (follow macOS standards)
AppMetrics.cornerRadiusLarge    // 12pt - Cards and containers
AppMetrics.cornerRadiusMedium   // 8pt - Buttons and elements
AppMetrics.cornerRadiusSmall    // 6pt - Compact elements
AppMetrics.cornerRadiusXSmall   // 4pt - Inline elements

// Spacing
AppMetrics.spacingXLarge        // 24pt
AppMetrics.spacingLarge         // 20pt
AppMetrics.spacing              // 16pt (standard)
AppMetrics.spacingMedium        // 12pt
AppMetrics.spacingSmall         // 8pt
AppMetrics.spacingXSmall        // 4pt

// Icon sizes
AppMetrics.iconSizeLarge        // 20pt
AppMetrics.iconSize             // 16pt (standard)
AppMetrics.iconSizeSmall        // 14pt
AppMetrics.iconSizeXSmall       // 12pt

// Button sizes
AppMetrics.buttonSizeLarge      // 40pt
AppMetrics.buttonSize           // 32pt (standard)
AppMetrics.buttonSizeSmall      // 28pt
```

### 4. Animation Timing

Consistent motion creates a cohesive feel:

```swift
// Use predefined animations
withAnimation(AppAnimations.hoverEasing) {
    isHovering = true
}

withAnimation(AppAnimations.springEasing) {
    isExpanded.toggle()
}

// Available curves
AppAnimations.hoverEasing       // 70ms ease-out (fast hover)
AppAnimations.standardEasing    // 150ms ease-in-out (transitions)
AppAnimations.springEasing      // Responsive spring (interactive)
AppAnimations.subtleSpring      // Gentle spring (smooth motion)
```

---

## Component Library

### HoverIconButton

Icon-only button with hover effects and multiple variants.

**Basic Usage:**
```swift
HoverIconButton(
    systemName: "gear",
    action: { openSettings() }
)
```

**Destructive Variant:**
```swift
HoverIconButton(
    systemName: "trash",
    action: { deleteItem() },
    destructive: true
)
```

**Accent Variant:**
```swift
HoverIconButton(
    systemName: "star.fill",
    action: { toggleFavorite() },
    accent: true
)
```

**Custom Configuration:**
```swift
HoverIconButton(
    systemName: "arrow.right",
    action: { proceed() },
    tint: .blue,
    hoverTint: .blue.opacity(0.8),
    size: AppMetrics.buttonSizeLarge,
    iconSize: AppMetrics.iconSizeLarge,
    cornerRadius: AppMetrics.cornerRadiusMedium
)
```

### GlassButton

Full button with text, optional icon, and glass styling.

**Style Variants:**
```swift
// Primary - Accent color fill
GlassButton(
    title: "Continue",
    systemImage: "arrow.right",
    action: { proceed() },
    style: .primary
)

// Secondary - Transparent with border
GlassButton(
    title: "Cancel",
    systemImage: nil,
    action: { cancel() },
    style: .secondary
)

// Destructive - Red tint
GlassButton(
    title: "Delete",
    systemImage: "trash",
    action: { delete() },
    style: .destructive
)

// Accent - Accent color fill
GlassButton(
    title: "Save",
    systemImage: "checkmark",
    action: { save() },
    style: .accent
)
```

**Size Variants:**
```swift
GlassButton(title: "Small", systemImage: nil, action: {}, size: .small)
GlassButton(title: "Medium", systemImage: nil, action: {}, size: .medium)
GlassButton(title: "Large", systemImage: nil, action: {}, size: .large)
```

### GlassCard

Container component for grouping related content.

**Basic Card:**
```swift
GlassCard {
    VStack(alignment: .leading) {
        Text("Title").font(.headline)
        Text("Description").font(.caption)
    }
}
```

**Custom Configuration:**
```swift
GlassCard(
    material: AppMaterial.secondaryGlass,
    cornerRadius: AppMetrics.cornerRadiusMedium,
    padding: AppMetrics.paddingLarge,
    borderColor: AppColors.accent,
    showBorder: true
) {
    // Content
}
```

**Hoverable Card (Interactive):**
```swift
HoverableGlassCard(
    action: { selectCard() }
) {
    VStack {
        Text("Tap me!")
    }
}
```

---

## Design Patterns

### 1. Hover States

All interactive elements should respond to hover:

```swift
@State private var isHovering = false

var body: some View {
    content
        .background(isHovering ? AppColors.hoverOverlay : .clear)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(AppAnimations.hoverEasing) {
                isHovering = hovering
            }
        }
}
```

### 2. Rounded Corners

Always use continuous corner style:

```swift
RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusMedium, style: .continuous)
```

### 3. Glass Layering

Layer glass materials for depth:

```swift
VStack {
    // Content
}
.background(AppMaterial.secondaryGlass)  // Inner layer
.padding()
.background(AppMaterial.primaryGlass)    // Outer layer
```

### 4. Icon + Text Labels

Use consistent spacing and sizing:

```swift
HStack(spacing: AppMetrics.spacingSmall) {
    Image(systemName: "calendar")
        .font(.system(size: AppMetrics.iconSize, weight: .semibold))
    Text("Events")
        .font(.system(size: 16, weight: .semibold))
}
.foregroundStyle(.primary)
```

---

## Implementation Guidelines

### Do ✅

- **Use semantic color names:** `AppColors.primary` not `Color.black`
- **Use metric constants:** `AppMetrics.spacing` not `16`
- **Use predefined animations:** `AppAnimations.hoverEasing` not custom timings
- **Apply continuous corner style:** `.continuous` on all `RoundedRectangle`
- **Animate hover states:** Always use `.onHover` with animation
- **Layer glass materials:** Create depth with multiple glass layers

### Don't ❌

- **Hard-code colors:** Avoid literal `Color.white`, `Color.gray`, etc.
- **Hard-code dimensions:** No magic numbers like `12`, `8`, etc.
- **Mix animation timings:** Use consistent curves from `AppAnimations`
- **Forget hover feedback:** Interactive elements need visual response
- **Overuse glass:** Not every element needs glass material
- **Skip accessibility:** Always provide `.help()` tooltips on buttons

---

## Examples from Codebase

### HomeView

The home screen demonstrates proper theme usage:

- Layered glass cards for content sections
- Consistent spacing with `AppMetrics`
- Hover-responsive rows
- Semantic color usage throughout

### TitleBarView

The title bar shows button patterns:

- `HoverIconButton` for navigation
- Active state highlighting with accent color
- Proper spacing and sizing
- Tooltip help text

### EventSummaryRow & NoteSummaryRow

These rows demonstrate:

- Hover scale effects
- Continuous rounded corners
- Glass backgrounds with borders
- Icon + text label patterns

---

## Future Enhancements

Potential additions to the Theme system:

1. **Typography System:** Font styles and text hierarchies
2. **Effects Module:** Shadows, blurs, and advanced effects
3. **Additional Components:**
   - Toggle switches
   - Input fields
   - Dropdown menus
   - Modal overlays
4. **Dark Mode Support:** Theme variants for appearance modes
5. **Accessibility Helpers:** Color contrast utilities, dynamic type support

---

## Contributing

When adding new components:

1. Place them in the appropriate `Components/` subfolder
2. Use existing theme constants (no hard-coded values)
3. Include hover states for interactive elements
4. Provide size and style variants where appropriate
5. Add preview code demonstrating usage
6. Update this README with examples

---

**Last Updated:** November 7, 2025

