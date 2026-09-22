# Doctest Runner for Zed

Run C++ doctest test cases with one click! This extension adds ▶️ play buttons in the gutter next to your TEST_CASE declarations, allowing you to run individual tests quickly.

## Features

- Detects `TEST_CASE`, `TEST_CASE_FIXTURE`, and `SCENARIO` macros
- Detects `TEST_SUITE("name") { ... }` blocks, with its own play button to run
  every test in the suite (`doctest`'s `--ts`/`--test-suite` filter)
- Provides runnable ▶️ buttons in the editor gutter
- Run individual tests with Cmd+Shift+R or by clicking the play button
- Integrates with Zed's native task system

## Installation

### As a Dev Extension (Local Development)

1. Clone or download this repository
2. Open Zed
3. Press **Cmd+Shift+P** and type "extensions: install dev extension"
4. Select the `zed-doctest-runner` directory

## Setup

**Important:** This is a two-step, one-time setup per project — Zed won't apply this
extension's queries to your files automatically (see "Why the language is called
"C++ (Doctest)"" below for why), and it needs a task to actually run your tests.

### Step 1: Opt your files into the "C++ (Doctest)" language

Add (or extend) `.zed/settings.json` in your project root:

```json
{
  "file_types": {
    "C++ (Doctest)": ["cpp", "cc", "cxx", "hpp", "h", "hh", "hxx"]
  }
}
```

Adjust the suffix list to match whichever files actually contain your doctest
`TEST_CASE`/`SCENARIO` macros — if you only want this for a `tests/` folder, keep
your day-to-day C++ files off this list so they keep using Zed's regular C++ support.

### Step 2: Create `.zed/tasks.json` in your project

In your C++ project root, create a `.zed/tasks.json` file with one of the configurations below:

#### Option A: Direct Test Executable

If you know the path to your test executable, and don't need `TEST_SUITE` support:

```json
[
  {
    "label": "Run doctest",
    "command": "./build/tests",
    "args": ["--test-case=*$ZED_CUSTOM_test_name", "--no-colors"],
    "tags": ["doctest-runner-test"]
  }
]
```

Replace `./build/tests` with your actual test executable path. The leading `*` on
`--test-case` is required for `SCENARIO`-based tests — see the note under Option C.
Keep the `label` static (don't embed `$ZED_CUSTOM_test_name` in it) — see the note
on terminal reuse under Option C for why.

#### Option B: Using CMake/CTest

If you use CMake and CTest:

```json
[
  {
    "label": "Run doctest",
    "command": "ctest",
    "args": ["--test-dir", "build", "-R", "$ZED_CUSTOM_test_name", "--verbose"],
    "tags": ["doctest-runner-test"]
  }
]
```

#### Option C: Separate Build Task + One Consolidated Run Task (recommended)

Rebuilding on every single test click is slow, so it's worth having one dedicated
build task. And rather than one run task per runnable kind (test / suite / whole
file), a single run task can bind to all three tags at once — `tags` accepts an
array — and branch internally on whichever variable actually got captured for that
click. This is what this repo's own `.zed/tasks.json` does:

```json
[
  {
    "label": "zed-doctest-runner: Build tests",
    "command": "mkdir -p build && c++ -std=c++17 -o build/tests \"$ZED_FILE\"",
    "use_new_terminal": false
  },
  {
    "label": "zed-doctest-runner: Run",
    "command": "[ -x build/tests ] || { echo 'build/tests not found - run the \"zed-doctest-runner: Build tests\" task first'; exit 1; }; test_name=\"${ZED_CUSTOM_test_name:}\"; suite_name=\"${ZED_CUSTOM_test_suite_name:}\"; if [ -n \"$test_name\" ]; then ./build/tests --test-case=\"*$test_name\" --no-colors; elif [ -n \"$suite_name\" ]; then ./build/tests --ts=\"*$suite_name\" --no-colors; else ./build/tests --no-colors; fi",
    "tags": [
      "doctest-runner-test",
      "doctest-runner-suite",
      "doctest-runner-main"
    ],
    "use_new_terminal": false,
    "reveal": "no_focus"
  }
]
```

Run "zed-doctest-runner: Build tests" once (Cmd+Shift+P → "task: spawn") after you
open the project and after any code change, then the play buttons stay fast — they
just exec the existing binary. The `[ -x build/tests ] || ...` guard gives a clear
message instead of a confusing "No such file or directory" if you click a test
before building.

**Why the tags are namespaced (`doctest-runner-*`, not `cpp-main` etc.):** tags
aren't scoped per-language or per-extension — Zed matches them globally against
every `tasks.json` on the system. Zed's own _built-in_ C++ language already uses
the tag `cpp-main` for its default "run this file's `main()`" runnable. Reusing
that generic name here would risk either our doctest binary running for an
unrelated plain-C++ project, or some other `cpp-main` task running instead of ours
— see "How It Works" below for the full reasoning.

**Why one task can serve three different runnable kinds:** `runnables.scm` tags a
`TEST_CASE`/`SCENARIO` as `doctest-runner-test` (capturing `@test_name`), a
`TEST_SUITE` block as `doctest-runner-suite` (capturing `@test_suite_name`), and
`main()` as `doctest-runner-main` (capturing neither). Whichever one you click,
only its own variable is ever populated for that specific run — the other is
simply absent from that click's context. Referencing an absent variable directly
(`$ZED_CUSTOM_test_name` with no fallback) would make Zed silently exclude the
whole task for that click (per Zed's docs: "task definitions with variables which
are not present... are filtered out"), so instead the command uses Zed's
`${VAR:default_value}` fallback syntax with an empty default
(`${ZED_CUSTOM_test_name:}`) to always resolve to _some_ string — that string is
then captured into a shell variable, and an `if`/`elif`/`else` picks the right
doctest filter (or no filter, for `main()`) based on which one is actually
non-empty.

> **This one part is unverified against a running Zed** — I've confirmed the
> shell branching itself is correct by simulating all three resolved command
> forms directly, but Zed's docs only demonstrate the `${VAR:default}` fallback
> syntax with built-in variables (`$ZED_FILE`, `$ZED_SELECTED_TEXT`), not with a
> `$ZED_CUSTOM_*` one, and I have no way to run the real Zed task-resolution
> engine from here. If clicking `TEST_SUITE`/`main()` play buttons stops working
> after this change (e.g. the task disappears from the picker, or errors with a
> literal `${ZED_CUSTOM_test_name:}` in the output instead of a resolved value),
> that means the fallback isn't supported for custom variables, and the fix is to
> go back to three separate tasks (one per tag, no fallback needed) — the previous
> working version of this file, before this consolidation.

`TEST_SUITE("math") { TEST_CASE(...) { ... } ... }` gets its own play button (on
the `TEST_SUITE` line itself, separate from each nested `TEST_CASE`'s own button).
`TEST_SUITE_BEGIN`/`TEST_SUITE_END` (the alternative non-block form) aren't
detected yet.

**Keep `label` static — don't put a variable in it.** Zed's terminal reuse
(`use_new_terminal: false`) is keyed off the _resolved_ task, and the label is
part of that. A label that embeds a variable would make every differently-resolved
click look like a different task, so instead of reusing one tab, Zed would open a
new one per distinct thing you've run. A static label collapses every run back
into one reused tab regardless of what was clicked — the terminal's own output
(the echoed command, then doctest's own summary) still shows you what actually ran.

The leading `*` in `--test-case="*$test_name"` matters: doctest's `SCENARIO` macro
prefixes the real test name with `"Scenario: "` internally, so a plain (non-wildcard)
match against the captured name silently runs zero tests for any `SCENARIO`. The `*`
wildcard makes the filter match the captured name as a suffix, which works for both
`TEST_CASE` (no prefix) and `SCENARIO` (`"Scenario: "` prefix) without ever matching
an unrelated test.

**On `use_new_terminal`/`reveal`:** `"use_new_terminal": false` (the default,
listed explicitly here for clarity) makes reruns reuse the same terminal tab
instead of piling up new ones. `"reveal": "no_focus"` on the run task shows the
output without yanking editor focus away every time you click a play button —
useful once you're running tests rapidly while still coding. Drop it (or set it
to `"always"`) if you'd rather the terminal always jump into focus.

### Step 3: Use It!

1. Build once: Cmd+Shift+P → "task: spawn" → "zed-doctest-runner: Build tests" (repeat after code changes)
2. Open a C++ file with doctest test cases
3. Look for ▶️ play buttons in the gutter next to `TEST_CASE` declarations
4. Click the button or:
   - Place cursor in a test case
   - Press **Cmd+Shift+R** (macOS) or **Ctrl+Shift+R** (Linux/Windows)
   - Or **Cmd+Shift+P** → "task: rerun"

## Example Test File

See `example_test.cpp` in this repo for a working copy (needs `doctest.h` from
[doctest/doctest](https://github.com/doctest/doctest) placed alongside it, and the
`file_types`/`tasks.json` setup below — this repo's own `.zed/` already has both).

```cpp
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"

TEST_CASE("Addition works correctly") {  // ▶️ play button appears here
    CHECK(1 + 1 == 2);
    CHECK(2 + 2 == 4);
}

TEST_CASE("Subtraction works correctly") {  // ▶️ play button appears here
    CHECK(5 - 3 == 2);
    CHECK(10 - 7 == 3);
}

SCENARIO("Testing multiplication") {  // ▶️ play button appears here
    GIVEN("two numbers") {
        int a = 3;
        int b = 4;

        WHEN("multiplied") {
            int result = a * b;

            THEN("the result is correct") {
                CHECK(result == 12);
            }
        }
    }
}

TEST_SUITE("math") {  // ▶️ play button here runs every test in this suite
    TEST_CASE("multiplication") { CHECK(3 * 4 == 12); }  // ▶️ and each still gets its own
    TEST_CASE("division") { CHECK(10 / 2 == 5); }
}
```

## Variables Available in Tasks

- `$ZED_CUSTOM_test_name` - The test case name (e.g., "Addition works correctly").
  Note this is **not** `$ZED_SYMBOL` — see "How It Works" below for why.
- `$ZED_CUSTOM_test_suite_name` - The `TEST_SUITE` name (e.g., "math"), captured
  the same way as `$ZED_CUSTOM_test_name` but from the `doctest-runner-suite` tag.
- `$ZED_FILE` - Full path to the current file
- `$ZED_WORKTREE_ROOT` - Project root directory
- `$ZED_ROW` - Current line number

## Troubleshooting

### No play buttons appear

1. **Check `file_types` is set for this project**: Step 1 above. Without it, your
   `.cpp` files stay on Zed's built-in "C++" language, which this extension never
   touches — no `file_types` entry means no play buttons, full stop.
2. **Check the extension is installed**: Cmd+Shift+P → "extensions" → verify "Doctest Runner" is listed as "Installed (dev)"
3. **Check the language picker** (bottom-right status bar, on the file's language
   name) shows **"C++ (Doctest)"**, not plain "C++", when the test file is open.
   If it still says "C++", `file_types` isn't matching — check the suffix list.
4. **Verify TEST_CASE syntax**: Make sure you're using `TEST_CASE("test name")` with quotes
5. **Check Zed's log** for load errors: Cmd+Shift+P → "zed: open log" (on macOS
   also readable directly at `~/Library/Logs/Zed/Zed.log`), search for `doctest` or
   `cpp_doctest`. A single invalid tree-sitter query anywhere in `languages/cpp_doctest/`
   blocks the _entire_ language from loading, not just that one query file.
6. **Reload extensions**: Cmd+Shift+P → "zed: reload extensions" (faster than
   reinstalling) after any change to files under `languages/` or `extension.toml`.

### "Task not found" error

You need to create `.zed/tasks.json` with a task that has a matching tag — e.g.
`"tags": ["doctest-runner-test"]` for a `TEST_CASE`, `"doctest-runner-suite"` for a
`TEST_SUITE`, `"doctest-runner-main"` for `main()`. See Setup instructions above.

### Test doesn't run / executable not found

1. **Verify test executable path** in your `.zed/tasks.json`
2. **Build your project first**: with the Option C split-task setup, run
   "zed-doctest-runner: Build tests" via Cmd+Shift+P → "task: spawn" (the run
   tasks intentionally don't build — see Option C above); otherwise run whatever
   build command your task uses
3. **Check executable exists**: `ls build/` (or wherever your executable should be)
4. **Use absolute paths** if relative paths don't work:
   ```json
   "command": "$ZED_WORKTREE_ROOT/build/tests"
   ```

### Test runs all tests instead of just one

Make sure your task includes the doctest filter, with the `*` prefix (needed for
`SCENARIO` tests — see Option C above):

```json
"args": ["--test-case=*$ZED_CUSTOM_test_name"]
```

The `$ZED_CUSTOM_test_name` variable will be replaced with the actual test name.

## How It Works

This extension uses Zed's **Runnables** system:

1. Tree-sitter queries (in `runnables.scm`) detect `TEST_CASE`/`SCENARIO`,
   `TEST_SUITE`, and `main()` in your C++ code
2. Each gets its own tag — `doctest-runner-test`, `doctest-runner-suite`,
   `doctest-runner-main` — via `(#set! tag ...)`. The tag is what binds a runnable
   to a task; the task's `label` is just display text and has no effect on this
3. Your task configuration's `tags` array is matched against that tag — a single
   task can list multiple tags, which is how one task ends up handling all three
   kinds of doctest runnable (see Option C above)
4. Zed displays ▶️ buttons and executes the matching task when clicked. If more
   than one `tasks.json` defines a task for the same tag, precedence is: workspace
   `.zed/tasks.json` > global `~/.config/zed/tasks.json` > a language extension's
   own default binding

### Why `$ZED_CUSTOM_test_name`, not `$ZED_SYMBOL`

`$ZED_SYMBOL` is **not** populated from `runnables.scm`'s `@run` capture. It comes
from a separate mechanism — the outline/breadcrumb symbol Zed's outline query
(`outline.scm`) resolves at the cursor's position. For most language test runners
(e.g. a Rust `#[test] fn foo()`), that happens to work because the tested function
is _also_ a normal outline item, so `$ZED_SYMBOL` naturally resolves to its name.
`TEST_CASE("...")` is a macro call, not a declaration `outline.scm` recognizes, so
`$ZED_SYMBOL` is simply undefined at that position — and per Zed's docs, a task
referencing a variable that isn't available gets silently filtered out of the task
picker (and the play button does nothing, for the same reason).

The fix: `runnables.scm` captures the test name string a second time under a
distinct name (`@test_name`, alongside `@run`), which Zed exposes to the task as
`$ZED_CUSTOM_test_name` — the same mechanism the official `package.json` runnables
example uses for `@script`. This is reliable regardless of what (if anything)
`outline.scm` says about the surrounding code.

### Why the language is called "C++ (Doctest)" and needs `file_types`

Zed's C++ support (syntax highlighting, brackets, indentation, the `cpp` grammar,
etc.) is built directly into Zed itself, not loaded from an extension. Extensions
cannot attach extra queries (like `runnables.scm`) to that built-in language, and
Zed actively refuses to let an extension re-register a grammar or language name
that's already built in — confirmed from Zed's own log:

```
WARN not registering extension grammar cpp: a native grammar with this name is already registered
WARN not registering extension language C++: a language with this name is already registered outside of extensions
```

So this extension ships its own separately-named language, **"C++ (Doctest)"**,
with a full set of query files (`highlights.scm`, `brackets.scm`, `indents.scm`,
etc., alongside `runnables.scm`) so it looks and behaves just like normal C++ —
plus doctest run buttons. Those query files started from Zed's own built-in C++
ones (GPL-licensed, see `zed-industries/zed:crates/grammars/src/cpp`) — fine for
local/dev use, but worth knowing before publishing this extension publicly under
the MIT license this repo currently claims.

**Its grammar is `grammar = "cpp"` — the same name as the native one, reused by
reference.** This is deliberate and required, not a leftover: tree-sitter-cpp's
compiled output always exports a C symbol literally named `tree_sitter_cpp`
(hardcoded in the grammar's own source). An earlier version of this extension
tried registering it under a different name (`[grammars.cpp_doctest]`) to "own" a
copy — that failed to link (`symbol exported via --export not found:
tree_sitter_cpp_doctest`), which in turn made the whole language fail to load
repeatedly, which (see next paragraph) broke C++ file detection **globally**, in
every Zed window, not just this project. Referencing Zed's already-compiled
native `cpp` grammar by name instead means there's nothing to build, and it's
guaranteed to be the exact grammar version these query files were written against.

**This language also declares no `path_suffixes`, `modeline_aliases`, or
`first_line_pattern` on purpose.** Extensions register languages globally, not
per-project. If this language listed `.cpp`/`.h`/etc. as suffixes (like the native
one does), it would become a second candidate for those files in _every_ Zed
project you open — and if it ever failed to load again (a bad query file, a typo),
every `.cpp`/`.h` file everywhere would show "Unknown" again, not just this repo's.
The only way to activate this language is the explicit `file_types` override in a
project's own `.zed/settings.json` (Step 1) — that's a deliberate safety boundary,
not a missing feature.

## Limitations

- Extension cannot provide default tasks (Zed limitation) - users must configure `.zed/tasks.json`
- Test output appears in terminal, not inline
- No test panel UI (tracked in [Zed Issue #5242](https://github.com/zed-industries/zed/issues/5242))
- Cannot auto-detect test executable path

## Future Enhancements

When Zed adds these features, we can:

- Provide default task templates automatically
- Add inline test results
- Create a dedicated test panel UI
- Auto-detect CMake build directories and test executables

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
