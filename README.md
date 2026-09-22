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

If you know the path to your test executable:

```json
[
  {
    "label": "Run doctest",
    "command": "./build/tests",
    "args": ["--test-case=*$ZED_CUSTOM_test_name", "--no-colors"],
    "tags": ["cpp-doctest-test"]
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
    "tags": ["cpp-doctest-test"]
  }
]
```

#### Option C: Separate Build Task + Run Tasks (recommended)

Rebuilding on every single test click is slow. Better to have one dedicated build
task, and have the run tasks just run. This is what this repo's own
`.zed/tasks.json` does:

```json
[
  {
    "label": "Build tests",
    "command": "mkdir -p build && c++ -std=c++17 -o build/tests \"$ZED_FILE\"",
    "use_new_terminal": false
  },
  {
    "label": "Run doctest",
    "command": "[ -x build/tests ] || { echo 'build/tests not found - run the \"Build tests\" task first'; exit 1; }; ./build/tests --test-case=\"*$ZED_CUSTOM_test_name\" --no-colors",
    "tags": ["cpp-doctest-test"],
    "use_new_terminal": false,
    "reveal": "no_focus"
  },
  {
    "label": "Run doctest suite",
    "command": "[ -x build/tests ] || { echo 'build/tests not found - run the \"Build tests\" task first'; exit 1; }; ./build/tests --ts=\"*$ZED_CUSTOM_test_suite_name\" --no-colors",
    "tags": ["cpp-doctest-suite"],
    "use_new_terminal": false,
    "reveal": "no_focus"
  }
]
```

`TEST_SUITE("math") { TEST_CASE(...) { ... } ... }` gets its own play button (on
the `TEST_SUITE` line itself, separate from each nested `TEST_CASE`'s own button),
bound to the `cpp-doctest-suite` tag and doctest's `--ts`/`--test-suite` filter —
`--test-case` won't match a suite name. `TEST_SUITE_BEGIN`/`TEST_SUITE_END` (the
alternative non-block form) aren't detected yet.

Run "Build tests" once (Cmd+Shift+P → "task: spawn" → "Build tests") after you open
the project and after any code change, then the play buttons stay fast — they just
exec the existing binary. The `[ -x build/tests ] || ...` guard gives a clear
message instead of a confusing "No such file or directory" if you click a test
before building.

**Keep `label` static — don't put `$ZED_CUSTOM_test_name` in it.** Zed's terminal
reuse (`use_new_terminal: false`) is keyed off the *resolved* task, and the label
is part of that. A label that embeds the test name makes every different test you
click look like a different task, so instead of reusing one tab, Zed opens a new
one per distinct test you've run. A static label (just `"Run doctest"`) collapses
every test run back into one reused tab regardless of which test was clicked — the
terminal's own output (the echoed command, then doctest's own summary) still shows
you which test actually ran.

The leading `*` in `--test-case="*$ZED_CUSTOM_test_name"` matters: doctest's `SCENARIO` macro
prefixes the real test name with `"Scenario: "` internally, so a plain (non-wildcard)
match against `$ZED_CUSTOM_test_name` silently runs zero tests for any `SCENARIO`. The `*`
wildcard makes the filter match the captured name as a suffix, which works for both
`TEST_CASE` (no prefix) and `SCENARIO` (`"Scenario: "` prefix) without ever matching
an unrelated test.

**On `use_new_terminal`/`reveal`:** `"use_new_terminal": false` (the default,
listed explicitly here for clarity) makes reruns reuse the same terminal tab
instead of piling up new ones. `"reveal": "no_focus"` on the run tasks shows the
output without yanking editor focus away every time you click a play button —
useful once you're running tests rapidly while still coding. Drop it (or set it
to `"always"`) if you'd rather the terminal always jump into focus.

### Step 3: Use It!

1. Build once: Cmd+Shift+P → "task: spawn" → "Build tests" (repeat after code changes)
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
  the same way as `$ZED_CUSTOM_test_name` but from the `cpp-doctest-suite` tag.
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

You need to create `.zed/tasks.json` with a task that has `"tags": ["cpp-doctest-test"]`. See Setup instructions above.

### Test doesn't run / executable not found

1. **Verify test executable path** in your `.zed/tasks.json`
2. **Build your project first**: with the Option C split-task setup, run "Build
   tests" via Cmd+Shift+P → "task: spawn" (the run tasks intentionally don't build
   — see Option C above); otherwise run whatever build command your task uses
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

1. Tree-sitter queries (in `runnables.scm`) detect TEST_CASE macros in your C++ code
2. Detected test cases are tagged with `cpp-doctest-test`
3. Your task configuration matches this tag
4. Zed displays ▶️ buttons and executes the task when clicked

### Why `$ZED_CUSTOM_test_name`, not `$ZED_SYMBOL`

`$ZED_SYMBOL` is **not** populated from `runnables.scm`'s `@run` capture. It comes
from a separate mechanism — the outline/breadcrumb symbol Zed's outline query
(`outline.scm`) resolves at the cursor's position. For most language test runners
(e.g. a Rust `#[test] fn foo()`), that happens to work because the tested function
is *also* a normal outline item, so `$ZED_SYMBOL` naturally resolves to its name.
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
one does), it would become a second candidate for those files in *every* Zed
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
