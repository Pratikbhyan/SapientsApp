# Product Requirements Document (PRD)
# Audio Player iOS App with Text Synchronization and Image Display

## Table of Contents
1. [Introduction](#introduction)
2. [Product Overview](#product-overview)
3. [User Interface Design](#user-interface-design)
4. [Functional Requirements](#functional-requirements)
5. [Visual Effects and Transcription Synchronization](#visual-effects-and-transcription-synchronization)
6. [Technical Requirements](#technical-requirements)
7. [Implementation Considerations](#implementation-considerations)
8. [Appendix](#appendix)

## Introduction

### Purpose
This document outlines the product requirements for enhancing an iOS audio player application with improved UI and additional features including favorites functionality, dynamic visual effects, and synchronized text transcription.

### Scope
The scope includes UI redesign based on the provided mockup, implementation of favorites functionality, 10-second skip controls, blur effects during playback, and improved transcription synchronization with visual highlighting.

### Target Audience
- iOS app developers
- UI/UX designers
- Project managers
- QA testers

## Product Overview

### Current State
The application currently has basic functionality with:
- Audio playback capability
- Backend integration for audio files
- Basic text synchronization with audio

### Desired Enhancements
1. Redesigned UI matching the provided mockup
2. Larger thumbnail images with aesthetic improvements
3. 10-second skip forward and backward controls
4. Favorites functionality for saving and accessing content
5. Dynamic blur effects on images during playback
6. Title dimming during playback
7. Enhanced transcription synchronization with visual highlighting

### Success Criteria
- UI matches the provided design mockup
- All new features function as specified
- Smooth transitions and effects during playback
- Intuitive user experience for managing favorites
- Accurate synchronization between audio and text

## User Interface Design

### Main Player Screen

#### Header Section
- **App Title**
  - Position: Top-left of screen
  - Typography: 28pt, Bold, San Francisco font
  - Color: #000000 (Black)
  
- **Date Display**
  - Position: Below app title, left-aligned
  - Typography: 18pt, Regular, San Francisco font
  - Color: #000000 (Black)
  - Format: "Month DD" (e.g., "May 21")

#### Content Display
- **Thumbnail/Artwork**
  - Size: Full width of screen, approximately 70% of screen height
  - Corner Radius: 16pt
  - Shadow: Subtle drop shadow (opacity: 0.1, y-offset: 2pt, blur: 4pt)
  
- **Content Title**
  - Position: Top-left area of thumbnail, with adequate padding (16pt from edges)
  - Typography: 24pt, Bold, San Francisco font
  - Color: #000000 (Black) with adequate contrast against background
  - Background: Semi-transparent container if needed for legibility

#### Playback Controls
- **Control Container**
  - Position: Bottom area of thumbnail
  - Background: Semi-transparent overlay (opacity: 0.3)
  - Height: Approximately 80pt
  
- **Skip Back Button**
  - Position: Left side of control container
  - Icon: Double chevron left or custom rewind icon
  - Size: 44pt x 44pt (minimum touch target)
  - Label: Optional "10s" indicator
  
- **Play/Pause Button**
  - Position: Center of control container
  - Icon: Play/pause icon
  - Size: 60pt x 60pt (larger than skip buttons)
  - Background: Light circular background for contrast
  
- **Skip Forward Button**
  - Position: Right side of control container
  - Icon: Double chevron right or custom forward icon
  - Size: 44pt x 44pt (minimum touch target)
  - Label: Optional "10s" indicator

#### Navigation Bar
- **Container**
  - Position: Bottom of screen
  - Height: 60pt (standard iOS tab bar height)
  - Background: White (#FFFFFF)
  - Border: Subtle top border (1pt, #E0E0E0)
  
- **Tab Items**
  - Size: Equal width, 1/3 of screen width each
  - Icons: Home, Favorites (bookmark), Profile
  - Labels: Below icons, 12pt, Regular
  - Active State: Bold text, highlighted icon
  - Inactive State: Regular text, standard icon

### Favorites Screen

#### Header Section
- **Back Button**
  - Position: Top-left
  - Icon: Left chevron
  - Size: 44pt x 44pt (minimum touch target)
  
- **Screen Title**
  - Position: Center-aligned at top
  - Typography: 20pt, Bold, San Francisco font
  - Text: "Favorites"
  
- **Subheader**
  - Position: Left-aligned below main header
  - Typography: 24pt, Bold, San Francisco font
  - Text: "Topics"
  - Margin: 16pt from top and left edges

#### Favorites List
- **List Container**
  - Position: Below subheader
  - Padding: 16pt horizontal
  - Spacing: 16pt between items
  
- **List Item**
  - Height: Approximately 80pt
  - Background: Optional subtle background (#F8F8F8)
  - Corner Radius: 8pt
  
- **Item Thumbnail**
  - Position: Left side of item
  - Size: 60pt x 60pt
  - Corner Radius: 8pt
  - Border: Optional 1pt subtle border (#E0E0E0)
  
- **Item Title**
  - Position: Right of thumbnail, 12pt margin
  - Typography: 16pt, Medium, San Francisco font
  - Color: #000000 (Black)
  
- **Item Duration**
  - Position: Below title
  - Typography: 14pt, Regular, San Francisco font
  - Color: #707070 (Gray)
  - Format: "XX min" (e.g., "14 min")

### Interaction Specifications

#### Audio Playback Controls
- **Play/Pause Button**
  - When tapped in paused state:
    - Icon changes from play to pause
    - Audio playback begins
    - Image background blurs (blur radius: 10pt)
    - Content title dims (opacity reduces to 0.7)
    - Current transcription sentence is highlighted
  - When tapped in playing state:
    - Icon changes from pause to play
    - Audio playback pauses
    - Image background blur is removed
    - Content title returns to full opacity
    - Transcription highlighting pauses at current position

- **Skip Back Button**
  - When tapped:
    - Audio position jumps back 10 seconds
    - Brief visual feedback (button highlight)
    - Transcription updates to match new position
    - If at beginning of audio, remains at start position

- **Skip Forward Button**
  - When tapped:
    - Audio position jumps forward 10 seconds
    - Brief visual feedback (button highlight)
    - Transcription updates to match new position
    - If near end of audio, jumps to end and pauses playback

#### Favorites Functionality
- **Favorite Button**
  - Position: Top-right corner of player screen
  - Icon: Outline heart/bookmark when not favorited
  - Size: 44pt x 44pt (minimum touch target)
  
- **Add to Favorites**
  - When tapped in unfavorited state:
    - Icon changes to filled heart/bookmark
    - Brief haptic feedback (light)
    - Item is added to favorites list
    - Optional toast notification: "Added to Favorites"
  
- **Remove from Favorites**
  - When tapped in favorited state:
    - Icon changes to outline heart/bookmark
    - Brief haptic feedback (light)
    - Item is removed from favorites list
    - Optional toast notification: "Removed from Favorites"

#### Screen Navigation
- **Favorites Tab**
  - When tapped:
    - UI transitions to Favorites screen
    - Tab is highlighted as active
    - Favorites list is displayed
    - If playing, audio continues in background

- **Back Button (on Favorites screen)**
  - When tapped:
    - UI returns to previous screen
    - If coming from player, returns to player screen
    - If coming from home, returns to home screen

## Functional Requirements

### Favorites Functionality

#### Data Model Requirements

- **Favorite Item Structure**
  - Each favorite item must store:
    - Unique identifier
    - Content title
    - Thumbnail image reference
    - Audio file reference
    - Duration in minutes/seconds
    - Date added to favorites
    - Optional: Last played position

- **Data Persistence**
  - Favorites must be persisted locally using:
    - UserDefaults for simple implementations
    - Core Data for more complex implementations with search/filter capabilities
    - Supabase backend synchronization for cross-device access
  - Favorites data should persist across app launches and updates

#### User Interactions

- **Adding to Favorites**
  - Trigger Methods:
    - Tapping the favorite button on the player screen
    - Optional: Long-press context menu on content list items
  
  - System Behavior:
    - Check if item already exists in favorites
    - If not present: Add item to favorites collection
    - If already present: Show feedback that item is already in favorites
    - Update UI to reflect favorited state (filled icon)
    - Provide haptic and visual feedback confirming the action

- **Removing from Favorites**
  - Trigger Methods:
    - Tapping the favorite button when item is already favorited
    - Swipe-to-delete on the favorites list
    - Optional: Edit mode in favorites list
  
  - System Behavior:
    - Remove item from favorites collection
    - Update UI to reflect unfavorited state (outline icon)
    - Provide haptic and visual feedback confirming the action
    - If removed while viewing favorites list, animate item removal

- **Viewing Favorites**
  - Access Methods:
    - Dedicated favorites tab in the navigation bar
    - Optional: Favorites section on home screen
  
  - Display Requirements:
    - Sort by most recently added by default
    - Optional: Allow sorting by title, duration, or most played
    - Display thumbnail, title, and duration for each item
    - Support for pull-to-refresh to update list
    - Empty state handling with appropriate messaging

- **Favorite Item Selection**
  - Behavior:
    - Tapping a favorite item navigates to the player screen
    - Player loads the selected content
    - Optional: Resume from last played position if available

#### Edge Cases and Error Handling

- **Offline Access**
  - Favorites must be accessible when device is offline
  - Appropriate messaging if content requires download

- **Sync Conflicts**
  - If implementing cross-device sync, handle merge conflicts appropriately
  - Prioritize most recent changes when resolving conflicts

- **Storage Limitations**
  - Handle cases where favorite count becomes very large
  - Optional: Implement pagination for large favorites collections

### Playback Functionality

#### Core Playback Features

- **Audio Loading and Preparation**
  - Support for streaming from remote URLs
  - Support for local file playback
  - Preloading/buffering for smoother playback
  - Format support for MP3 files (primary) and other common formats
  - Error handling for unavailable or corrupted audio files

- **Basic Controls**
  - Play/Pause:
    - Toggle between play and pause states
    - Update UI to reflect current state
    - Handle audio session interruptions (calls, notifications)
    - Resume from same position after interruption when appropriate

  - 10-Second Skip Controls:
    - Skip backward: Move playback position back 10 seconds
    - Skip forward: Move playback position forward 10 seconds
    - Boundary handling: Prevent skipping before start or after end
    - Update transcription position to match new audio position

- **Playback State Management**
  - Track current playback position in seconds
  - Calculate and display remaining time
  - Support background playback
  - Update lock screen with playback information
  - Handle app backgrounding and foregrounding

#### Advanced Playback Features

- **Playback Speed**
  - Support multiple playback speeds (0.5x, 1.0x, 1.5x, 2.0x)
  - Maintain audio pitch when changing speed
  - Persist user's preferred playback speed

- **Audio Quality**
  - Adapt streaming quality based on network conditions
  - Optional: Allow user to select quality preference
  - Handle transitions between network states (WiFi to cellular)

- **Position Memory**
  - Remember playback position for each content item
  - Resume from last position when reopening content
  - Optional: Ask user whether to resume or start over if significant time has passed

#### Background Behavior

- **Background Playback**
  - Continue playback when app enters background
  - Support background fetch for streaming content
  - Implement proper audio session management

- **Lock Screen Controls**
  - Display content information on lock screen
  - Provide transport controls on lock screen
  - Update lock screen information as content changes

- **Audio Session Management**
  - Handle interruptions (phone calls, alarms)
  - Pause playback for short interruptions
  - Provide option to resume after long interruptions
  - Respect system audio routing changes

## Visual Effects and Transcription Synchronization

### Blur Effects

#### Implementation Requirements

- **Blur Effect on Playback**
  - Trigger Conditions:
    - Activated when audio playback begins
    - Deactivated when audio playback pauses
    - Deactivated when audio playback completes

  - Visual Specifications:
    - Target Element: Background image/artwork
    - Blur Type: Gaussian blur
    - Blur Radius: 10pt (configurable based on design preference)
    - Blur Animation: Smooth transition over 300ms
    - Opacity: Maintain full opacity (1.0) with blur effect

  - Technical Implementation:
    - Use SwiftUI's `.blur(radius:)` modifier
    - Animate changes using `.animation(.easeInOut(duration: 0.3), value: isPlaying)`
    - Ensure blur effect is applied to image only, not to overlaid controls or text

- **Title Dimming Effect**
  - Trigger Conditions:
    - Synchronized with blur effect activation/deactivation
    - Activated when audio playback begins
    - Deactivated when audio playback pauses

  - Visual Specifications:
    - Target Element: Content title text
    - Opacity Change: From 1.0 (full opacity) to 0.7 (dimmed)
    - Transition: Smooth fade over 300ms
    - Text Legibility: Must remain readable even when dimmed

  - Technical Implementation:
    - Use SwiftUI's `.opacity()` modifier
    - Animate changes using the same animation timing as blur effect
    - Ensure text remains accessible and meets contrast requirements even when dimmed

#### State Management

- **Playback State Tracking**
  - Maintain single source of truth for playback state
  - Ensure UI effects are synchronized with actual audio playback
  - Handle state changes from multiple sources (user interaction, system events)

- **Effect Coordination**
  - Ensure blur and dimming effects are applied/removed simultaneously
  - Coordinate with transcription highlighting for cohesive experience
  - Handle rapid state changes gracefully (multiple play/pause taps)

### Transcription Synchronization

#### Text-Audio Synchronization

- **Timestamp Mapping**
  - Data Structure:
    - Each transcription segment must contain:
      - Text content (sentence)
      - Start time in milliseconds
      - End time in milliseconds
      - Optional: Confidence score

  - Synchronization Logic:
    - Track current audio position in milliseconds
    - Compare position against transcription segment timestamps
    - Identify current active segment based on time range containment
    - Update UI to highlight active segment

- **Playback Position Changes**
  - Update highlighted segment immediately when:
    - Normal playback progresses to new segment
    - User skips forward/backward
    - User seeks to specific position via progress bar
  - Handle boundary cases (start of audio, end of audio)

#### Visual Highlighting

- **Active Segment Styling**
  - Visual Specifications:
    - Background Color: Light blue (#E6F2FF) or brand-appropriate highlight color
    - Text Style: Medium or Bold weight
    - Text Color: #000000 (Black) or high-contrast color
    - Border: Optional subtle rounded border
    - Transition: Smooth color/style change over 200ms

  - Technical Implementation:
    - Use conditional styling based on active segment index
    - Apply consistent highlighting across all instances of text display
    - Ensure highlight is visually distinct but not distracting

- **Inactive Segment Styling**
  - Visual Specifications:
    - Background: None or subtle (#F8F8F8)
    - Text Style: Regular weight
    - Text Color: #707070 (Gray) or reduced contrast color
    - Transition: Smooth color/style change when becoming inactive

#### Auto-Scrolling Behavior

- **Scroll Management**
  - Auto-scroll to keep active segment visible
  - Position active segment at optimal reading position (upper third of visible area)
  - Implement smooth scrolling animation between segments
  - Avoid jarring scroll jumps between distant segments

- **User Interaction**
  - Allow manual scrolling by user
  - Pause auto-scroll when user manually scrolls
  - Resume auto-scroll after period of inactivity (5 seconds)
  - Provide visual indicator when auto-scroll is active/paused

## Technical Requirements

### Development Environment

- **Platform Requirements**
  - iOS 15.0 or later
  - Swift 5.5 or later
  - Xcode 13.0 or later
  - SwiftUI for UI implementation

- **Backend Integration**
  - Continue using existing Supabase backend
  - Ensure API compatibility with new features
  - Implement proper error handling for network operations

### Performance Requirements

- **Responsiveness**
  - UI must remain responsive during all operations
  - Animations must maintain 60fps on supported devices
  - Audio playback must be smooth without interruptions

- **Memory Management**
  - Efficient image caching for thumbnails
  - Proper resource management for audio playback
  - Minimize memory footprint for transcription data

- **Battery Efficiency**
  - Optimize network operations to reduce battery impact
  - Implement efficient background playback
  - Consider reduced effects for low battery situations

### Accessibility Requirements

- **Voice Over Support**
  - All interactive elements must have appropriate accessibility labels
  - Playback controls should announce their function and current state
  - Transcription should be navigable by Voice Over

- **Dynamic Type**
  - Text elements should support Dynamic Type for user-preferred text sizes
  - Layout should adapt gracefully to larger text sizes

- **Reduced Motion**
  - Alternative transitions should be available when Reduce Motion is enabled
  - Blur effects should be subtle or optional

- **Color Contrast**
  - All text must maintain minimum 4.5:1 contrast ratio against backgrounds
  - Interactive elements should be distinguishable without relying solely on color

## Implementation Considerations

### Development Approach

- **UI Implementation**
  - Use SwiftUI for all new UI components
  - Implement custom modifiers for reusable styling
  - Create view models to separate business logic from UI

- **State Management**
  - Use ObservableObject pattern for shared state
  - Implement proper state synchronization between components
  - Consider using Combine framework for reactive updates

- **Testing Strategy**
  - Unit tests for business logic
  - UI tests for critical user flows
  - Performance testing for animations and effects
  - Accessibility testing with VoiceOver

### Timeline and Priorities

- **Phase 1: Core UI Updates**
  - Implement new player screen layout
  - Add 10-second skip controls
  - Update navigation and tab bar

- **Phase 2: Visual Effects**
  - Implement blur effects during playback
  - Add title dimming
  - Enhance transcription highlighting

- **Phase 3: Favorites Functionality**
  - Implement favorites data model
  - Create favorites UI
  - Add favorite/unfavorite interactions

- **Phase 4: Polish and Optimization**
  - Refine animations and transitions
  - Optimize performance
  - Enhance accessibility support

## Appendix

### Design References
- Provided mockup showing player and favorites screens
- iOS Human Interface Guidelines

### Technical References
- SwiftUI documentation
- AVFoundation documentation
- Supabase Swift SDK documentation

### Glossary
- **Blur Effect**: Visual effect that applies Gaussian blur to an image
- **Transcription Synchronization**: Process of highlighting text in sync with audio playback
- **Favorites**: User-saved content items for quick access
