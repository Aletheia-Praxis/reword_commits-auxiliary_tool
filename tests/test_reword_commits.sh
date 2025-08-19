#!/bin/bash

# shellcheck disable=SC1090,SC1091

set -x

# Mock the exit function to prevent script from exiting during tests
exit() {
  _last_exit_code=$1
}

# Mock the printf function to capture its output
printf() {
  _captured_printf_output+="$(printf '%b' "$@")"
}

# Helper function to reset captured output
reset_mocks() {
  _last_exit_code=0
  _captured_printf_output=""
}

setUp() {
  reset_mocks
  # Create a temporary directory for Git tests
  _test_git_root="$(mktemp -d)"
  export GIT_TOPLEVEL_DIR="$_test_git_root"
  mkdir -p "$_test_git_root/.git"
  # Mimic a minimal Git repository state if needed for common mocks
}

tearDown() {
  # Clean up the temporary directory
  rm -rf "$_test_git_root"
}

# tests/test_reword_commits.sh

# Add path to shunit2
SHUNIT2_PATH="$(dirname "$0")/shunit2/shunit2"

# Import functions for testing
source "$(dirname "$0")/../reword_commits.sh"

test_display_help() {
  display_help
  local expected_output
  expected_output="\nUsage: reword_commits.sh [OPTIONS]\nScript for interactively rewriting Git commit messages.\n\nOptions:\n  -h, --help                      Show this help message and exit.\n  -d, --default                   Use default Git editor selection (GIT_EDITOR, EDITOR, then nano).\n  -e <EDITOR>, --editor=<EDITOR>  Specify the Git editor to use (e.g., nano, vim, code --wait).\n\nExamples:\n  reword_commits.sh\n  reword_commits.sh --help\n  reword_commits.sh --editor=vim\n  reword_commits.sh -e code --wait\n  reword_commits.sh --default\n\n"
  assertEquals "0" "$_last_exit_code"
  assertEquals "$expected_output" "$_captured_printf_output"
}

mock_read() {
  REPLY="$1"
}

# Test for get_rebase_option (valid input)
test_get_rebase_option_valid() {
  (echo "2") | {
    local result
    result=$(get_rebase_option)
    assertEquals "2" "$result"
  }
}

# Test for get_num_commits (valid input)
test_get_num_commits_valid() {
  (echo "5") | {
    local result
    result=$(get_num_commits)
    assertEquals "5" "$result"
  }
}

# Test for determine_git_editor with CUSTOM_EDITOR

test_determine_git_editor_custom() {
  local CUSTOM_EDITOR="vim"
  local USE_DEFAULT_EDITOR=false
  local result
  result=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")
  assertEquals "vim" "$result"
}

# Test for determine_git_editor with GIT_EDITOR

test_determine_git_editor_git_env() {
  local CUSTOM_EDITOR=""
  local USE_DEFAULT_EDITOR=false
  # shellcheck disable=SC2034
  local GIT_EDITOR="nano"
  local result
  result=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")
  assertEquals "nano" "$result"
}

# Test for determine_git_editor with EDITOR

test_determine_git_editor_editor_env() {
  local CUSTOM_EDITOR=""
  local USE_DEFAULT_EDITOR=false
  # shellcheck disable=SC2034
  local GIT_EDITOR=""
  # shellcheck disable=SC2034
  local EDITOR="micro"
  local result
  result=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")
  assertEquals "micro" "$result"
}

# Test for determine_git_editor with default

test_determine_git_editor_default() {
  local CUSTOM_EDITOR=""
  local USE_DEFAULT_EDITOR=false
  # shellcheck disable=SC2034
  local GIT_EDITOR=""
  # shellcheck disable=SC2034
  local EDITOR=""
  local result
  result=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")
  assertEquals "nano" "$result"
}

# Test for get_stash_choice with 's' input

test_get_stash_choice_stash() {
  (echo "s") | {
    local result
    result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_stash_choice with 'e' input

test_get_stash_choice_exit() {
  (echo "e") | {
    local result
    result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Test for get_stash_choice with invalid then valid input

test_get_stash_choice_invalid_then_stash() {
  (echo "x"; echo "s") | {
    local result
    result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_rebase_option with invalid then valid input

test_get_rebase_option_invalid_then_valid() {
  (echo "x"; echo "4"; echo "2") | {
    local result
    result=$(get_rebase_option)
    assertEquals "2" "$result"
  }
}

# Test for get_num_commits with invalid then valid input

test_get_num_commits_invalid_then_valid() {
  (echo "-1"; echo "abc"; echo "0"; echo "3") | {
    local result
    result=$(get_num_commits)
    assertEquals "3" "$result"
  }
}

# Test for get_stash_choice with uppercase S

test_get_stash_choice_uppercase_S() {
  (echo "S") | {
    local result
    result=$(get_stash_choice)
    assertEquals "s" "$result"
  }
}

# Test for get_stash_choice with uppercase E

test_get_stash_choice_uppercase_E() {
  (echo "E") | {
    local result
    result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Test for get_stash_choice with multiple invalid then valid input

test_get_stash_choice_multiple_invalid_then_exit() {
  (echo "foo"; echo "bar"; echo "e") | {
    local result
    result=$(get_stash_choice)
    assertEquals "e" "$result"
  }
}

# Mocks for git commands to isolate main function tests
# shellcheck disable=SC2317
git() {
  case "$1" in
    "rev-parse")
      if [[ "$2" == "--show-toplevel" ]]; then
        echo "${GIT_TOPLEVEL_DIR:-/mock/git/root}"
      elif [[ "$2" == "--abbrev-ref" ]] && [[ "$3" == "HEAD" ]]; then
        echo "mock-branch"
      elif [[ "$2" == "--verify" ]]; then
        echo "mockfullhash123456789012345678901234567890"
      else
        echo ""
      fi
      ;;
    "diff")
      # Simulate no changes by default
      return 0
      ;;
    "stash")
      # Simulate successful stash
      return 0
      ;;
    "cat-file")
      # Simulate commit existence
      return 0
      ;;
    "rebase")
      if [[ "$_rebase_continue_fail" == "true" ]]; then
        _rebase_continue_fail=false # Reset for next call
        return 1
      fi
      return 0
      ;;
    "status")
      printf '%b' "On branch mock-branch\nnothing to commit, working tree clean"
      return 0
      ;;
    *)
      printf '%s' "mock git command: $*" >&2
      return 1
      ;;
  esac
}

test_main_no_args() {
  reset_mocks # Ensure mocks are clean for this test
  main # Call main with no arguments
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Usage: reword_commits.sh\" ]]" # Check for help message
}

# Test for main with --help argument (should display help)
test_main_help_arg() {
  reset_mocks
  main "--help"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Usage: reword_commits.sh\" ]]"
}

# Test for main with -h argument (should display help)
test_main_h_arg() {
  reset_mocks
  main "-h"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Usage: reword_commits.sh\" ]]"
}

test_main_invalid_arg() {
  reset_mocks
  main "--invalid"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Invalid argument --invalid\" ]]"
}

test_main_editor_missing_arg() {
  reset_mocks
  main "-e"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Missing argument for -e\" ]]"
}

test_main_editor_with_arg() {
  reset_mocks
  (echo "1"; echo "n") | main "-e" "vim"
  assertEquals "0" "$_last_exit_code"
}

test_main_editor_equals_arg() {
  reset_mocks
  (echo "1"; echo "n") | main "--editor=code --wait"
  assertEquals "0" "$_last_exit_code"
}

test_main_default_editor() {
  reset_mocks
  (echo "1"; echo "n") | main "--default"
  assertEquals "0" "$_last_exit_code"
}

test_main_not_in_git_repo() {
  reset_mocks
  # Temporarily override git rev-parse to simulate not being in a repo
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "rev-parse" ]]; then
      echo ""
      return 1
    else
      command git "$@"
    fi
  }
  main "--help"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Could not find Git repository root directory.\" ]]"
}

test_main_uncommitted_changes_stash() {
  reset_mocks
  # Mock git diff to simulate uncommitted changes
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "diff" ]]; then
      return 1 # Simulate changes exist
    elif [[ "$1" == "stash" ]]; then
      return 0 # Simulate successful stash
    else
      command git "$@"
    fi
  }
  (echo "s"; echo "1"; echo "n") | main "--default"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Stashing uncommitted changes...\" ]]"
}

test_main_uncommitted_changes_exit() {
  reset_mocks
  # Mock git diff to simulate uncommitted changes
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "diff" ]]; then
      return 1 # Simulate changes exist
    else
      command git "$@"
    fi
  }
  (echo "e") | main "--default"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Exiting script. Please commit or discard your changes manually.\" ]]"
}

test_main_stash_fail() {
  reset_mocks
  # Mock git diff to simulate uncommitted changes, and git stash to fail
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "diff" ]]; then
      return 1 # Simulate changes exist
    elif [[ "$1" == "stash" ]]; then
      return 1 # Simulate stash failure
    else
      command git "$@"
    fi
  }
  (echo "s") | main "--default"
  assertEquals "1" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Failed to stash changes. Please resolve the issue manually and try again.\" ]]"
}

test_main_rebase_from_root() {
  reset_mocks
  (echo "1"; echo "n") | main "--default"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Starting Git Rebase in interactive mode for all commits from the beginning...\" ]]"
}

test_main_rebase_last_n_commits() {
  reset_mocks
  (echo "2"; echo "5"; echo "n") | main "--default"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Starting Git Rebase in interactive mode for the last 5 commits...\" ]]"
}

test_main_rebase_specific_commit() {
  reset_mocks
  (echo "3"; echo "abcdef7"; echo "n") | main "--default"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Starting Git Rebase in interactive mode to reword commit mockfullhash123456789012345678901234567890...\" ]]"
}

test_main_rebase_specific_commit_empty_hash() {
  reset_mocks
  (echo "3"; echo ""; echo "n") | main "--default"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Commit hash cannot be empty.\" ]]"
}

test_main_rebase_specific_commit_invalid_format() {
  reset_mocks
  (echo "3"; echo "invalidhash"; echo "n") | main "--default"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Invalid commit hash format.\" ]]"
}

test_main_rebase_specific_commit_nonexistent() {
  reset_mocks
  # Mock git rev-parse to simulate non-existent commit
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "rev-parse" && "$2" == "--verify" ]]; then
      echo ""
      return 1
    else
      command git "$@"
    fi
  }
  (echo "3"; echo "abcdef7"; echo "n") | main "--default"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Commit with hash 'abcdef7' does not exist in the repository or is ambiguous.\" ]]"
}

test_main_rebase_specific_commit_cat_file_fail() {
  reset_mocks
  # Mock git cat-file to simulate non-existent commit
  # shellcheck disable=SC2317
  git() {
    if [[ "$1" == "cat-file" ]]; then
      return 1
    else
      command git "$@"
    fi
  }
  (echo "3"; echo "abcdef7"; echo "n") | main "--default"
  assertEquals "2" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error: Commit with hash 'abcdef7' does not exist in the repository.\" ]]"
}

# Tests for handle_paused_rebase
test_handle_paused_rebase_continue_success() {
  reset_mocks
  # Simulate rebase-merge directory exists
  mkdir "$_test_git_root/.git/rebase-merge"
  
  (echo "c") | handle_paused_rebase "$_test_git_root"
  assertEquals "0" "$_last_exit_code"
  assertFalse "[[ -d \"$_test_git_root/.git/rebase-merge\" ]]" # Should be gone after successful continue
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Git Rebase operation completed.\" ]]"
}

test_handle_paused_rebase_continue_fail() {
  reset_mocks
  # Simulate rebase-merge directory exists and git rebase --continue fails
  mkdir "$_test_git_root/.git/rebase-merge"
  _rebase_continue_fail=true # Flag to make git rebase return 1
  
  (echo "c"; echo "q") | handle_paused_rebase "$_test_git_root"
  assertEquals "0" "$_last_exit_code" # Exits with 0 if user quits after failure
  assertTrue "[[ -d \"$_test_git_root/.git/rebase-merge\" ]]" # Should still exist
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Error continuing rebase. Please resolve conflicts manually or abort rebase.\" ]]"
}

test_handle_paused_rebase_abort() {
  reset_mocks
  # Simulate rebase-merge directory exists
  mkdir "$_test_git_root/.git/rebase-merge"
  
  (echo "a") | handle_paused_rebase "$_test_git_root"
  assertEquals "0" "$_last_exit_code"
  assertFalse "[[ -d \"$_test_git_root/.git/rebase-merge\" ]]" # Should be gone after abort
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Git Rebase aborted.\" ]]"
}

test_handle_paused_rebase_quit() {
  reset_mocks
  # Simulate rebase-merge directory exists
  mkdir "$_test_git_root/.git/rebase-merge"
  
  (echo "q") | handle_paused_rebase "$_test_git_root"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ -d \"$_test_git_root/.git/rebase-merge\" ]]" # Should still exist
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Exiting script. Git Rebase remains in a paused state.\" ]]"
}

test_handle_paused_rebase_invalid_then_valid() {
  reset_mocks
  # Simulate rebase-merge directory exists
  mkdir "$_test_git_root/.git/rebase-merge"
  
  (echo "x"; echo "c") | handle_paused_rebase "$_test_git_root"
  assertEquals "0" "$_last_exit_code"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Invalid input. Please enter 'c', 'a', or 'q'.\" ]]"
  assertTrue "[[ \"$_captured_printf_output\" =~ \"Git Rebase operation completed.\" ]]"
}

# Run shunit2
. "$SHUNIT2_PATH" 