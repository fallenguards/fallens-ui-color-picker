# Changelog

## [1.2.0] - 2026-11-16

### Added
- Swing timers and Breath and fatigue bars rows under Themed, on by default, so those bars no longer go with Other windows. If Other windows was unchecked, both start unchecked and nothing changes until you check them. Swing timers shows on WoW Forever only, where the game has one.

### Changed
- The settings window opens at half its height with a scroll bar. Drag the grip in its bottom right corner to resize it; the size is kept. Wider, the Themed and Window pieces checkboxes spread into more columns.

### Fixed
- The error around combat when the target frame redrew could still come from the rim drawn around the target's and focus's aura icons; that now leaves those buttons alone too.

## [1.1.0] - 2026-11-08

### Added
- Window pieces: Borders, Buttons, Tabs, Scroll bars, Dropdowns and Backgrounds each have a checkbox under Themed, so the color can go on a window's borders alone and leave its buttons and backgrounds as drawn.
- A Bag slots row under Themed, on by default: the slot behind each bag, the empty slot's art and the key ring, takes the color. A bag's own icon stays with Bag icons.
- Classic Era, Season of Discovery included. There the micro menu, the key ring, close buttons and the action buttons take the color on their frames only: their icons, the key and the arrows keep their own colors.
- Bronze has its own darkness slider, like Dark: lighter to the left, black at the far right.
- A Page arrows row under Themed for the action bar's page arrows.
- On WoW Forever, a thank-you line at login with a link to report bugs. Its own link or the WoW Forever welcome row in the settings turns it off.

### Changed
- Chat windows are left out of the theme by default. The Chat row under Themed turns them on; a setting already saved keeps its value.
- The action bar's page arrows keep their yellow arrow; only the button around it takes the color.
- The latency light keeps its green, yellow or red.

### Fixed
- An error around combat on WoW Forever when the target frame redrew: the target's aura buttons refuse their name to addons, and the walk over the frame now leaves them alone.
- Square pieces of a frame now take the color with the rest of it: window corners, the portrait ring, the game menu's border corners and the ammo slot.
- EasyFind's panel beside the map takes the color with the map's border.

## [1.0.2] - 2026-10-30

### Fixed
- With the full ClassicUI Forever enabled, the notice that the picker stays off shows once instead of at every login. Its entry in the game's addon menu by the minimap still shows it.

## [1.0.1] - 2026-10-29

### Fixed
- On a character with the full ClassicUI Forever enabled, the picker now stays off instead of running beside it.

## [1.0.0] - 2026-10-29

### Added
- Recolor the game's whole interface in one place: Dark, with a slider from light gray to black; Bronze; or any color you pick.
- Textured color keeps the art's textures under the color; without it each part is one even color.
- A Background shade slider for parchment and window backgrounds: darker to the left, lighter to the right.
- Pick which parts take the color: unit frames, cast bars, nameplates, the minimap, action bars, the micro menu, bags, tooltips, menus, chat, the quest tracker, windows and other addons.
- Elite and rare dragons, on unit frames and nameplates, can keep their own gold or silver.
- A look pick at first login, a settings window (`/fcp`, the minimap button, or the game's AddOns list) and a minimap button: left-click for the settings, right-click for the look pick.
- With the full ClassicUI Forever enabled, the picker stays off and says so: ClassicUI Forever has the same colors built in.
