; Doctest TEST_CASE, TEST_CASE_FIXTURE, and SCENARIO macros
; Matches: TEST_CASE("test name") { ... }
;
; $ZED_SYMBOL is NOT populated from @run here — it comes from a separate mechanism
; (the outline/breadcrumb symbol at the cursor), which a macro call like TEST_CASE
; never populates. So the test name is captured a second time as @test_name, which
; Zed exposes to the bound task as $ZED_CUSTOM_test_name (see tasks.json).
((call_expression
  function: (identifier) @_test_macro
  (#match? @_test_macro "^(TEST_CASE|TEST_CASE_FIXTURE|SCENARIO)$")
  arguments: (argument_list
    (string_literal
      (string_content) @run @test_name))) @_cpp_doctest_test
  (#set! tag doctest-runner-test))

; Doctest TEST_SUITE blocks
; Matches: TEST_SUITE("suite name") { TEST_CASE(...) { ... } ... }
; Filtered differently from a single test (doctest's --ts/--test-suite, not
; --test-case), so it gets its own tag rather than reusing doctest-runner-test.
((call_expression
  function: (identifier) @_test_suite_macro
  (#eq? @_test_suite_macro "TEST_SUITE")
  arguments: (argument_list
    (string_literal
      (string_content) @run @test_suite_name))) @_cpp_doctest_suite
  (#set! tag doctest-runner-suite))

; Also detect main() function for running all tests.
;
; Tag is namespaced (doctest-runner-main, not the more obvious cpp-main) because
; Zed's own built-in C++ language uses "cpp-main" for this exact same purpose on
; plain main() functions. Tags aren't scoped per-language — they're matched
; globally against every tasks.json on the system — so reusing "cpp-main" here
; would risk either our doctest binary running for an unrelated C++ project, or
; some other "cpp-main" task running instead of ours, depending on precedence.
((function_definition
  declarator: (function_declarator
    declarator: (identifier) @run)) @_cpp_main
  (#eq? @run "main")
  (#set! tag doctest-runner-main))
