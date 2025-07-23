#!/bin/bash

# tests/test_reword_commits.sh

# Add path to shunit2
SHUNIT2_PATH="$(dirname "$0")/shunit2/shunit2"

# Import functions for testing
source "./reword_commits.sh"

# Mock the read function for get_rebase_option
mock_read() {
  REPLY="$1"
}

# Test for get_rebase_option (valid input)
test_get_rebase_option_valid() {
  (echo "2") | {
    local result=$(get_rebase_option)
    assertEquals "2" "$result"
  }
}

# Test for get_num_commits (valid input)
test_get_num_commits_valid() {
  (echo "5") | {
    local result=$(get_num_commits)
    assertEquals "5" "$result"
  }
}

# Test for determine_git_editor with CUSTOM_EDITOR

test_determine_git_editor_custom() {
  CUSTOM_EDITOR="vim"
  USE_DEFAULT_EDITOR=false
  local result=$(determine_git_editor)
  assertEquals "vim" "$result"
}

# Test for determine_git_editor with GIT_EDITOR

test_determine_git_editor_git_env() {
  CUSTOM_EDITOR=""
  USE_DEFAULT_EDITOR=false
  GIT_EDITOR="nano"
  local result=$(determine_git_editor)
  assertEquals "nano" "$result"
}

# Test for determine_git_editor with EDITOR

test_determine_git_editor_editor_env() {
  CUSTOM_EDITOR=""
  USE_DEFAULT_EDITOR=false
  GIT_EDITOR=""
  EDITOR="micro"
  local result=$(determine_git_editor)
  assertEquals "micro" "$result"
}

# Test for determine_git_editor with default

test_determine_git_editor_default() {
  CUSTOM_EDITOR=""
  USE_DEFAULT_EDITOR=false
  GIT_EDITOR=""
  EDITOR=""
  local result=$(determine_git_editor)
  assertEquals "nano" "$result"
}

# Test for get_stash_choice with 's' input

test_get_stash_choice_stash() {
  (echo "s") | {
    local result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_stash_choice with 'e' input

test_get_stash_choice_exit() {
  (echo "e") | {
    local result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Test for get_stash_choice with invalid then valid input

test_get_stash_choice_invalid_then_stash() {
  (echo "x"; echo "s") | {
    local result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_rebase_option with invalid then valid input

test_get_rebase_option_invalid_then_valid() {
  (echo "x"; echo "4"; echo "2") | {
    local result=$(get_rebase_option)
    assertEquals "2" "$result"
  }
}

# Test for get_num_commits with invalid then valid input

test_get_num_commits_invalid_then_valid() {
  (echo "-1"; echo "abc"; echo "0"; echo "3") | {
    local result=$(get_num_commits)
    assertEquals "3" "$result"
  }
}

# Test for get_stash_choice with uppercase S

test_get_stash_choice_uppercase_S() {
  (echo "S") | {
    local result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_stash_choice with uppercase E

test_get_stash_choice_uppercase_E() {
  (echo "E") | {
    local result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Test for get_stash_choice with multiple invalid then valid input

test_get_stash_choice_multiple_invalid_then_exit() {
  (echo "foo"; echo "bar"; echo "e") | {
    local result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Structure for handle_paused_rebase (mocking git)
# Full-fledged testing of handle_paused_rebase requires complex mocking of git and the file system,
# so here is only a template for future integration tests.

# Run shunit2
. "$SHUNIT2_PATH" 