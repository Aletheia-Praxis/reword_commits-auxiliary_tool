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

# Run shunit2
. "$SHUNIT2_PATH" 