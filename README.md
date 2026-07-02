# Emergent Fable Generator

A small Godot 4.7 simulation of eight animal-archetype agents — Fox, Owl, Hare, Bear, Crow, Mole, Badger, Wren — living among five locations, each with fixed personality traits, decaying needs, and relationships that shift with every interaction. A utility-AI tick loop drives their behavior; a chronicle system turns what happens into plain-English sentences and, once a day, a one-line moral. Agents who go too long without eating starve and are replaced by a successor who inherits a diluted share of their reputation.

No LLM calls, no external dependencies — pure Godot stdlib (GDScript, `RefCounted`, `Timer`, `RichTextLabel`).

*Built by Claude Sonnet 5. "Fable" in the name is a coincidence of the original workspace folder, not a reference to a different model of the same name.*

## Sample output

From an actual run (`chronicles/day_005.md`):

```
- Bear's greed got the better of them — they stole from Fox at the Market.
- Fox crept off with what belonged to Bear.
- Hare set off from the Meadow toward the Market.
- Wren set off from the Den toward the Meadow.
- Mole had always kept to the edges, and in the end the forest simply forgot to feed them.
- A new Mole came of age at the Den, inheriting a place in the forest — and, unknowing, some of what came before.
- Wren backed down from Badger.
```

More full days, several with a death and succession, are in [`chronicles/`](chronicles/).

## Running it

Requires Godot 4.7. Open `project.godot` in the editor and run `scenes/main.tscn`, or from the command line:

```sh
godot --path . scenes/main.tscn
```

Controls: pause, 1x/4x speed, running day counter. The chronicle scrolls live and exports to `chronicles/day_NNN.md` at each day's end.

To just watch it generate text without the UI:

```sh
godot --headless --path .
```

## Testing

```sh
godot --headless --script res://tests/self_check.gd
```

Asserts needs stay clamped, the forage economy never goes negative, roster size and generations stay sane through any deaths/successions, every location gets real (bounded) use — the permanent version of a bug a user caught by watching the game for thirty seconds, see [`REPORT.md`](REPORT.md) — and the chronicle produces varied, non-repeating output. Two sub-checks drive the death→succession path and the lineage-aware moral ("the third Fox in a row to die at the Market") directly, forcing scenarios the natural sim may not produce on its own.

Runs automatically on every push via [GitHub Actions](.github/workflows/self_check.yml).

## More

- [`REPORT.md`](REPORT.md) — architecture, design decisions, and a fairly detailed account of everything that went wrong along the way (three separate rounds of bugs that all invariant-checking and prose-reading missed, each caught a different way).
- [`JOURNAL.md`](JOURNAL.md) — process notes, written as it happened.

## License

MIT — see [`LICENSE`](LICENSE).
