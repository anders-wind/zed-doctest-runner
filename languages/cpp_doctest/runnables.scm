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
  (#set! tag cpp-doctest-test))

; Doctest TEST_SUITE blocks
; Matches: TEST_SUITE("suite name") { TEST_CASE(...) { ... } ... }
; Filtered differently from a single test (doctest's --ts/--test-suite, not
; --test-case), so it gets its own tag/task rather than reusing cpp-doctest-test.
((call_expression
  function: (identifier) @_test_suite_macro
  (#eq? @_test_suite_macro "TEST_SUITE")
  arguments: (argument_list
    (string_literal
      (string_content) @run @test_suite_name))) @_cpp_doctest_suite
  (#set! tag cpp-doctest-suite))

; Also detect main() function for running all tests
((function_definition
  declarator: (function_declarator
    declarator: (identifier) @run)) @_cpp_main
  (#eq? @run "main")
  (#set! tag cpp-main))
