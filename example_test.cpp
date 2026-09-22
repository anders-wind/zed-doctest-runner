// Example doctest file
// This demonstrates the different TEST_CASE patterns that the extension detects

#define DOCTEST_CONFIG_IMPLEMENT
#include "doctest.h"
#include <vector>

// Basic TEST_CASE - click the play button to run just this test
TEST_CASE("Addition works correctly") {
  CHECK(1 + 1 == 2);
  CHECK(2 + 2 == 4);
  CHECK(10 + 5 == 15);
}

// Another TEST_CASE - each gets its own play button
TEST_CASE("Subtraction works correctly") {
  CHECK(5 - 3 == 2);
  CHECK(10 - 7 == 3);
  REQUIRE(100 - 1 == 99);
}

// TEST_CASE with sections
TEST_CASE("Multiplication with sections") {
  int a = 2;
  int b = 3;

  SUBCASE("positive numbers") { CHECK(a * b == 6); }

  SUBCASE("with zero") { CHECK(a * 0 == 0); }
}

// SCENARIO is also detected
SCENARIO("Vector operations") {
  GIVEN("an empty vector") {
    std::vector<int> v;

    WHEN("an element is added") {
      v.push_back(1);

      THEN("the size becomes 1") { CHECK(v.size() == 1); }

      AND_THEN("the element is at index 0") { CHECK(v[0] == 1); }
    }
  }
}

// TEST_CASE_FIXTURE for test fixtures
struct MyFixture {
  int value = 42;
};

TEST_CASE_FIXTURE(MyFixture, "Using a fixture") {
  CHECK(value == 42);
  value = 100;
  CHECK(value == 100);
}

// TEST_SUITE groups test cases - click the play button on the TEST_SUITE line
// to run every test in the suite (doctest's --ts/--test-suite filter), separate
// from the play buttons on each TEST_CASE inside it
TEST_SUITE("math") {
  TEST_CASE("multiplication") { CHECK(3 * 4 == 12); }

  TEST_CASE("division") { CHECK(10 / 2 == 5); }
}

// You can also run main() to execute all tests
// The play button next to main() will run all tests
int main(int argc, char **argv) {
  doctest::Context context;
  context.applyCommandLine(argc, argv);
  int res = context.run();
  return res;
}
