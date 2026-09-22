# Doctest Runner for Zed

Run C++ doctest test cases with one click! This extension adds ▶️ play buttons in the gutter next to your `TEST_CASE`, `TEST_SUITE`, and `main()` declarations, letting you run an individual test, a whole suite, or everything.

Note this project is entirely vibe-coded - do with that as you may

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

### Step 2: Create `.zed/tasks.json` in your project

In your C++ project root, create a `.zed/tasks.json` file. This is what this
repo's own `.zed/tasks.json` uses — one build task, and one run task whose `tags`
array covers all three runnable kinds (test / suite / whole file):

```json
[
  {
    "label": "zed-doctest-runner: Run",
    "command": "./build/tests", // Put your test executable here
    "args": [
      "--test-case=\"*${ZED_CUSTOM_test_name:}\"",
      "--test-suite=\"*${ZED_CUSTOM_test_suite_name:}\""
    ],
    "tags": [
      // These tags are what connects the task to the extension
      "doctest-runner-test",
      "doctest-runner-suite",
      "doctest-runner-main"
    ],
    "use_new_terminal": false,
    "reveal": "no_focus"
  }
]
```

## Trying It Out (this repo's own tests)

To test out this repo locally, first run the "Fetch doctest.h" task, then the "Build tests" task.
Now you should be able to successfully press the test buttons in [./tests/example_test.cpp](./tests/example_test.cpp)

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
