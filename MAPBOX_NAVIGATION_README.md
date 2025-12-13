# Mapbox Enhanced Navigation Features

This document explains the new enhanced Mapbox navigation features available in your Flutter app and how to use each field.

## 🎯 Overview

Your app now supports advanced Mapbox navigation features that provide:
- **Voice Instructions** - Distance-triggered audio announcements
- **Banner Instructions** - Rich visual guidance with road signs
- **Lane Guidance** - Visual indicators showing which lanes to use
- **Enhanced Maneuvers** - Roundabout exits, road references, destinations
- **Traffic-Aware Routing** - Real-time traffic consideration

## 📋 API Request Configuration

To enable these features, send requests to your backend with these parameters:

```json
{
  "locations": [
    {"lat": 35.1856, "lng": 33.3823},
    {"lat": 35.1951, "lng": 33.3662}
  ],
  "profile": "driving-traffic",
  "alternatives": true,
  "voice_instructions": true,
  "banner_instructions": true,
  "voice_units": "metric",
  "language": "en",
  "roundabout_exits": true,
  "waypoint_names": false
}
```

## 📱 New Data Models & Usage

### MapboxVoiceInstruction
**Purpose**: Provides distance-triggered voice announcements for turn-by-turn navigation.

**Fields**:
- `distanceAlongGeometry` - Distance from start of step when this announcement should play (in meters)
- `announcement` - Human-readable text to speak ("In 400 meters, turn left onto Main Street")
- `ssmlAnnouncement` - SSML formatted text for better pronunciation (optional)

**Usage**: 
- Trigger voice announcements based on `distanceAlongGeometry`
- Use `announcement` for basic text-to-speech
- Use `ssmlAnnouncement` for natural pronunciation with advanced TTS engines
- Typically multiple announcements per step (at 800m, 200m, 50m distances)

### MapboxBannerInstruction
**Purpose**: Provides visual instruction banners that update dynamically during navigation.

**Fields**:
- `distanceAlongGeometry` - Distance when this banner should be displayed
- `primary` - Main instruction content (always present)
- `secondary` - Secondary instruction content (optional)
- `sub` - Additional instruction content (optional)

**Usage**:
- Display different banner content based on distance remaining
- Use `primary` for main navigation instruction
- Use `secondary` for additional context (road names, destinations)
- Update banner content dynamically as user approaches maneuvers

### MapboxBannerContent
**Purpose**: Contains the actual text and metadata for banner instructions.

**Fields**:
- `text` - Display text ("Turn left")
- `components` - Array of structured text parts for rich formatting
- `type` - Instruction type ("turn", "fork", "merge", "roundabout")
- `modifier` - Direction modifier ("left", "right", "straight", "slight_left")
- `degrees` - Turn angle in degrees for visual indicators (optional)
- `drivingSide` - Which side of road to drive on ("left"/"right") (optional)

**Usage**:
- Use `text` for simple text display
- Use `components` for rich text formatting (different colors for road names, exit numbers)
- Use `degrees` to show turn angle indicators
- Use `type` and `modifier` for maneuver-specific icons

### MapboxBannerComponent
**Purpose**: Individual parts of banner text for advanced formatting.

**Fields**:
- `text` - The text content ("Main Street", "Exit 42")
- `type` - Component type ("text", "exit-number", "delimiter", "icon")
- `abbreviation` - Shortened version ("St" instead of "Street") (optional)
- `abbreviationPriority` - Priority for showing abbreviation when space is limited (optional)

**Usage**:
- Style different components differently (green background for exit numbers, bold for street names)
- Use abbreviations when screen space is limited
- Handle special components like exit signs and delimiters

### MapboxLane
**Purpose**: Provides lane guidance information for intersections.

**Fields**:
- `valid` - Whether this lane can be used for the route (boolean)
- `active` - Whether this lane is recommended for the route (boolean)
- `indications` - Array of lane markings/directions (["left", "straight", "right"])

**Common `indications` values**:
- `"left"` - Left turn lane
- `"right"` - Right turn lane  
- `"straight"` - Straight/through lane
- `"slight_left"` - Slight left turn
- `"slight_right"` - Slight right turn
- `"uturn"` - U-turn lane

**Usage**:
- Show lane arrows 200-500 meters before intersections
- Highlight `active` lanes (recommended)
- Gray out invalid lanes (`valid: false`)
- Display multiple arrows per lane if it has multiple indications

### Enhanced MapboxIntersection
**Purpose**: Provides detailed intersection information including lane guidance.

**New Fields**:
- `inIndex` - Which bearing index the route enters from (optional)
- `outIndex` - Which bearing index the route exits to (optional)
- `lanes` - Array of `MapboxLane` objects for lane guidance
- `classes` - Road classification (["motorway", "trunk", "primary", "residential"])

**Usage**:
- Use `lanes` array to display lane guidance UI
- Use `classes` to understand road type and adjust UI accordingly
- Use bearing indices for advanced intersection visualization

### Enhanced MapboxManeuver
**Purpose**: Provides detailed maneuver information including roundabout data.

**New Fields**:
- `exit` - Roundabout exit number (1, 2, 3, etc.) (optional)
- `roundaboutExits` - Total number of exits in the roundabout (optional)

**Usage**:
- For roundabouts, display "Take exit 2 of 4"
- Show roundabout diagrams with exit numbers
- Use exit information for more precise voice instructions

### Enhanced MapboxStep
**Purpose**: Navigation step with comprehensive guidance data.

**New Fields**:
- `voiceInstructions` - Array of `MapboxVoiceInstruction` objects
- `bannerInstructions` - Array of `MapboxBannerInstruction` objects
- `ref` - Road reference number ("A1", "M25", "I-95") (optional)
- `destinations` - Destination signage ("Airport, City Center") (optional)
- `exits` - Exit information ("Exit 42A", "Exit 15B-C") (optional)
- `pronunciation` - Phonetic pronunciation guide (optional)
- `rotaryName` - Name of roundabout/rotary (optional)
- `rotaryPronunciation` - Phonetic pronunciation of roundabout name (optional)

**Usage**:
- Process `voiceInstructions` for distance-triggered audio
- Update UI with `bannerInstructions` based on distance
- Display road numbers from `ref` as highway shields
- Show destination information for highway signs
- Display exit numbers prominently for highway navigation
- Use pronunciation guides for text-to-speech

## 🎯 Implementation Strategy

### Voice Navigation
1. Monitor user's distance remaining to current maneuver
2. Check `voiceInstructions` array for instructions to trigger
3. Play announcement when `distanceAlongGeometry` threshold is reached
4. Use `ssmlAnnouncement` for better pronunciation if available

### Visual Banner Updates
1. Monitor distance to current maneuver
2. Find appropriate `bannerInstruction` based on distance
3. Update UI with `primary`, `secondary`, and `sub` content
4. Style components differently based on their `type`

### Lane Guidance
1. Show lane guidance 200-500m before intersections
2. Extract `lanes` from intersection data
3. Highlight `active` lanes, gray out invalid lanes
4. Display arrows based on `indications` array

### Road Information Display
1. Show highway shields using `ref` field
2. Display destination signs using `destinations` field  
3. Prominently show exit numbers from `exits` field
4. Use road `classes` to adjust UI styling

### Roundabout Handling
1. Check if maneuver `type` is "roundabout"
2. Display "Take exit X of Y" using `exit` and `roundaboutExits`
3. Show roundabout diagram with exit positions
4. Use `rotaryName` if available for voice instructions

## 🔧 Best Practices

1. **Performance**: Only process data for current and upcoming steps
2. **Timing**: Voice instructions should trigger precisely at specified distances
3. **Accessibility**: Ensure voice instructions work with device accessibility features
4. **Localization**: Use `language` parameter in API requests for multi-language support
5. **Fallbacks**: Always have fallback text if enhanced fields are missing
6. **Battery**: Cache voice instructions to avoid repeated TTS processing
7. **UI Updates**: Update navigation UI smoothly without jarring transitions

## 📍 Distance Management

- Voice instructions typically trigger at: 800m, 400m, 100m, and 50m before maneuvers
- Banner instructions update at: 500m, 200m, 100m, and 50m before maneuvers  
- Lane guidance appears: 200-500m before intersections
- All distances are in meters and measured along the route geometry

## 🌍 Multi-language Support

Set the `language` parameter in API requests:
- `"en"` - English
- `"es"` - Spanish  
- `"fr"` - French
- `"de"` - German
- And other supported languages

Voice instructions and banner text will be returned in the specified language.