# Notch Notes

A native macOS 14+ SwiftUI quick note app.

## Run

```sh
swift run
```

`swift run` is useful for development, but Terminal can remain the active keyboard target. For manual UI testing, build and open the app bundle instead:

```sh
./scripts/build-app.sh
open dist/NotchNotes.app
```

## Use

- Press `Option-Space` to toggle the floating quick pad near the top-center of the screen.
- Type a note and press `Command-Return` to save it.
- Press `Escape` to hide the quick pad without losing the current draft.
- Add tags directly in note text with hashtags like `#work`, `#Project-1`, or `#todo_item`.
- Open the menu bar item to show the quick pad, open the library, open settings, or quit.

## Test

```sh
swift test
```
