#!/usr/bin/env bash

# Exit Codes:
# 0: Script executed successfully or exited gracefully (e.g., after displaying help,
#    aborting rebase, or user choosing to exit).
# 1: General execution error occurred (e.g., failure during Git stash operation).
# 2: Invalid command-line argument, invalid user input, or environment error (e.g., not in a Git
#    repository, missing argument for --editor).

if [[ -z "${PROGNAME+x}" ]]; then
  PROGNAME_TEMP=$(basename "${BASH_SOURCE[0]}")
  readonly PROGNAME="${PROGNAME_TEMP}"
fi

# Function: display_help
# Description: Displays the script's help message, including usage, available options, and examples.
# Arguments: None
# Exit Code: 0 (Always exits after displaying help).
display_help() {
    printf "Usage: %s [OPTIONS]\n" "$PROGNAME" # Dynamically uses script name for usage.
    printf "Script for interactively rewriting Git commit messages.\n"
    printf "\n"
    printf "Options:\n"
    printf "  -h, --help                      Show this help message and exit.\n"
    printf "  -d, --default                   Use default Git editor selection (GIT_EDITOR, EDITOR, then nano).\n"
    printf "  -e <EDITOR>, --editor=<EDITOR>  Specify the Git editor to use (e.g., nano, vim, code --wait).\n"
    printf "\n"
    printf "Examples:\n"
    printf "  %s\n" "$PROGNAME"
    printf "  %s --help\n" "$PROGNAME"
    printf "  %s --editor=vim\n" "$PROGNAME"
    printf "  %s -e code --wait\n" "$PROGNAME"
    printf "  %s --default\n" "$PROGNAME"
    exit 0
}

# Function: get_rebase_option
# Description: Prompts the user to choose a rebase operation type (from root, last N commits, or specific commit).
# Arguments: None
# Returns: A string representing the validated choice ("1", "2", or "3").
get_rebase_option() {
    local choice="" # Stores user's input.
    while true; do
        read -r -p "Enter 1, 2 or 3: " choice
        if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
            printf "%s\n" "$choice"
            break
        else
            printf "%sInvalid choice. Please enter 1, 2 or 3.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2
        fi
    done
}

# Function: get_num_commits
# Description: Prompts the user to enter the number of recent commits to rewrite and validates the input.
# Arguments: None
# Returns: A string representing the validated positive integer number of commits.
get_num_commits() {
    local num_commits="" # Stores user's input.
    while true; do
        read -r -p "Enter the number of last commits you want to rewrite (e.g., 5 for the last 5 commits): " num_commits
        # Validates if the input is a positive integer.
        if [[ "$num_commits" =~ ^[0-9]+$ ]] && [[ "$num_commits" -ne 0 ]]; then
            printf "%s\n" "$num_commits"
            break
        else
            printf "%sInvalid input. Please enter a positive integer.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2
        fi
    done
}

# Function: get_stash_choice
# Description: Prompts the user to choose whether to stash uncommitted changes or exit the script.
# Arguments: None
# Returns: A string ("s" for stash and continue, "e" for exit).
get_stash_choice() {
    local stash_choice="" # Stores user's input.
    while true; do
        read -r -p "Do you want to (s) stash changes and continue, or (e) exit? " stash_choice
        case "$stash_choice" in
            s|S)
                printf "s\n"
                break
                ;;
            e|E)
                printf "e\n"
                break
                ;;
            *)
                printf "%sInvalid choice. Please enter 's' or 'e'.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2
                ;;
        esac
    done
}

# Function: determine_git_editor
# Description: Determines the Git editor to use based on script arguments and environment variables.
# Arguments:
#   $1 (boolean): USE_DEFAULT_EDITOR - true if the --default flag is used, false otherwise.
#   $2 (string): CUSTOM_EDITOR - the value of the -e or --editor argument.
# Returns: A string representing the determined editor command (e.g., "nano", "vim", "code --wait").
determine_git_editor() {
    local USE_DEFAULT_EDITOR="$1"
    local CUSTOM_EDITOR="$2"

    if [[ "$USE_DEFAULT_EDITOR" = false ]] && [[ -n "$CUSTOM_EDITOR" ]]; then
        printf "%s\n" "$CUSTOM_EDITOR"
    elif [[ -n "$GIT_EDITOR" ]]; then # Prioritize GIT_EDITOR environment variable.
        printf "%s\n" "$GIT_EDITOR"
    elif [[ -n "$EDITOR" ]]; then # Fallback to EDITOR environment variable.
        printf "%s\n" "$EDITOR"
    else # Default to 'nano' if no other editor is specified or found.
        printf "nano\n"
    fi
}

# Function: handle_paused_rebase
# Description: Manages a paused Git rebase operation, prompting the user for action (continue, abort, or exit).
# Arguments:
#   $1 (string): GIT_ROOT - the path to the root directory of the Git repository.
# Exit Code:
#   0 (Exits if the user chooses to abort rebase or exit the script).
handle_paused_rebase() {
    local user_action="" # Stores the user's choice for handling the rebase.
    local GIT_ROOT="$1"
    while true; do
        # Checks for the presence of the rebase-merge directory, indicating an active/paused rebase.
        if [[ -d "$GIT_ROOT/.git/rebase-merge" ]]; then
            printf "\n"
            printf "Git Rebase paused (likely on an 'edit' command or due to conflicts).\n"
            printf "Please check the status, resolve conflicts (if any), or review changes.\n"
            git status # Displays current Git status for user context.
            printf "\n"
            printf "If there are conflicts, resolve them, then stage the changes with 'git add <files>'.\n"
            read -r -p "Choose action: (c) - continue rebase, (a) - abort rebase, (q) - exit script: " user_action
            case "$user_action" in
                c|C) # User opts to continue the rebase.
                    if ! git rebase --continue; then # Attempts to continue rebase.
                        printf "%sError continuing rebase. Please resolve conflicts manually or abort rebase.%s\n" "${BOLD_RED}" "${RESET}" >&2
                        # Does not exit; allows re-prompting if continue fails.
                    fi
                    ;;
                a|A) # User opts to abort the rebase.
                    git rebase --abort
                    printf "Git Rebase aborted.\n"
                    exit 0
                    ;;
                q|Q) # User opts to exit the script, leaving rebase paused.
                    printf "Exiting script. Git Rebase remains in a paused state.\n"
                    exit 0
                    ;;
                *) # Handles invalid input.
                    printf "%sInvalid input. Please enter 'c', 'a', or 'q'.%s\n" "${BOLD_YELLOW}" "${RESET}"
                    ;;
            esac
        else
            printf "\n"
            printf "Git Rebase operation completed.\n"
            break # Exits loop once rebase is finished.
        fi
    done
}

# Function: main
# Description: The main entry point of the script. It parses command-line arguments, handles uncommitted
#              changes, prompts the user for the rebase type, executes the interactive rebase, and
#              provides post-rebase instructions.
# Arguments: All command-line arguments passed to the script.
# Exit Code:
#   0: Script completes successfully or exits gracefully (e.g., after aborting rebase).
#   1: General execution error (e.g., Git stash failure).
#   2: Invalid command-line argument, invalid user input, or environment error (e.g., not in a Git repository).
main() {
    set -eo pipefail # Exit immediately if a command exits with a non-zero status or if a command in a pipeline fails.

    if [[ "$#" -eq 0 ]]; then # If no arguments are provided, display help and exit.
        display_help
    fi

    local CUSTOM_EDITOR="" # Stores the custom editor specified by the user via arguments.
    local USE_DEFAULT_EDITOR=false # Flag to indicate if the --default option is used.

    # ANSI color codes for text formatting.
    local BOLD_RED
    local BOLD_YELLOW
    local RESET

    # Check for tput availability, TTY output, and NO_COLOR environment variable to enable/disable colors.
    if command -v tput &>/dev/null && [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        BOLD_RED=$(tput setaf 1)
        BOLD_YELLOW=$(tput setaf 3)
        RESET=$(tput sgr0)
    else
        BOLD_RED=""
        BOLD_YELLOW=""
        RESET=""
    fi

    # Parse command-line arguments.
    while (( "$#" )); do
        case "$1" in
            -h|--help) # Handles help option.
                display_help
                ;;
            -d|--default) # Handles default editor option.
                USE_DEFAULT_EDITOR=true
                shift
                ;;
            --editor=*) # Handles custom editor with assignment (e.g., --editor=vim).
                CUSTOM_EDITOR="${1#*=}"
                shift
                ;;
            -e|--editor) # Handles custom editor requiring a separate argument (e.g., -e vim).
                if [[ -n "$2" ]] && [[ "${2:0:1}" != "-" ]]; then
                    CUSTOM_EDITOR="$2"
                    shift 2
                else
                    printf "%sError: Missing argument for %s%s\n" "${BOLD_RED}" "$1" "${RESET}" >&2
                    exit 2
                fi
                ;;
            *) # Catches and reports invalid arguments.
                printf "%sError: Invalid argument %s%s\n" "${BOLD_RED}" "$1" "${RESET}" >&2
                exit 2
                ;;
        esac
    done

    printf "\n"
    printf "Script for interactive rewriting of commit messages.\n"
    printf "This script will use 'git rebase -i' to modify Git history.\n"
    printf "Be careful, changing history can have consequences.\n"
    printf "\n"

    local changes_stashed=false # Flag to track if uncommitted changes were stashed.

    local GIT_ROOT # Stores the root directory of the current Git repository.
    GIT_ROOT=$(git rev-parse --show-toplevel)
    readonly GIT_ROOT # Ensure GIT_ROOT is immutable.
    if [[ -z "$GIT_ROOT" ]]; then # Check if the script is run outside a Git repository.
        printf "%sError: Could not find Git repository root directory.%s\n" "${BOLD_RED}" "${RESET}" >&2
        exit 2
    fi

    # Check for and handle uncommitted changes before rebase to prevent data loss.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        printf "\n"
        printf "%sWarning: You have uncommitted changes or changes in the index.\n" "${BOLD_YELLOW}"
        printf "         Please commit or stash them before proceeding.%s\n" "${RESET}" >&2
        local stash_choice
        stash_choice=$(get_stash_choice)
        case "$stash_choice" in
            s|S) # User chooses to stash changes.
                printf "Stashing uncommitted changes...\n"
                # Stashes changes including untracked files with a descriptive message.
                if ! git stash push --include-untracked -m "Temporary stash on branch $(git rev-parse --abbrev-ref HEAD)"; then
                    printf "%sError: Failed to stash changes. Please resolve the issue manually and try again.%s\n" "${BOLD_RED}" "${RESET}" >&2
                    exit 1
                fi
                changes_stashed=true
                ;;
            e|E) # User chooses to exit.
                printf "Exiting script. Please commit or discard your changes manually.\n"
                exit 0
                ;;
        esac
    fi

    printf "Do you want to rewrite history from the very first commit (root) or only the last N commits?\n"
    printf "1. From the first commit (root): Rewrites all commits from the initial commit.\n"
    printf "2. Last N commits: Rewrites a specified number of recent commits.\n"
    printf "3. A specific commit by hash: Rewrites a single commit by its hash, \n"
    printf "   allowing for targeted message changes.\n"

    local rebase_choice
    rebase_choice=$(get_rebase_option)

    local rebase_command="" # Stores the argument for `git rebase -i`.

    if [[ "$rebase_choice" == "1" ]]; then
        rebase_command="--root" # Specifies rebase from the very first commit.
        printf "\n"
        printf "Starting Git Rebase in interactive mode for all commits from the beginning...\n"
    elif [[ "$rebase_choice" == "2" ]]; then
        local num_commits
        num_commits=$(get_num_commits)
        rebase_command="HEAD~""$num_commits" # Specifies rebase for the last N commits.
        printf "\n"
        printf "Starting Git Rebase in interactive mode for the last %s commits...\n" "$num_commits"
    elif [[ "$rebase_choice" == "3" ]]; then
        local commit_hash
        read -r -p "Enter the full or abbreviated commit hash you want to reword" \
                   " (e.g., 110a32b for abbreviated or full hash): " commit_hash
        
        if [[ -z "$commit_hash" ]]; then # Validates that the commit hash is not empty.
            printf "%sError: Commit hash cannot be empty.%s\n" "${BOLD_RED}" "${RESET}" >&2
            exit 2
        fi

        # Validates commit hash format (7 or 40 hexadecimal characters).
        if ! [[ "$commit_hash" =~ ^([0-9a-fA-F]{7}|[0-9a-fA-F]{40})$ ]]; then
            printf "%sError: Invalid commit hash format. Must be a 7-character abbreviated or\n" \
                   "40-character full hexadecimal string.%s\n" "${BOLD_RED}" "${RESET}" >&2
            exit 2
        fi

        local full_commit_hash # Resolves abbreviated hash to full hash for uniqueness.
        full_commit_hash=$(git rev-parse --verify "$commit_hash" 2>/dev/null)

        if [[ -z "$full_commit_hash" ]]; then # Checks if the commit exists or is ambiguous.
            printf "%sError: Commit with hash '%s' does not exist in the repository or is\n" \
                   "ambiguous.%s\n" "${BOLD_RED}" "${RESET}" "$commit_hash"
            exit 2
        fi

        commit_hash="$full_commit_hash" # Uses the full commit hash for rebase.

        # Verifies that the Git object (commit) exists.
        if ! git cat-file -e "$commit_hash" 2>/dev/null; then
            printf "%sError: Commit with hash '%s' does not exist in the repository.%s\n" "${BOLD_RED}" "${RESET}" "$commit_hash"
            exit 2
        fi

        rebase_command="%s~1" "$commit_hash" # Rebase on the parent of the commit to be reworded.
        printf "\n"
        printf "Starting Git Rebase in interactive mode to reword commit '%s'...\n" "$commit_hash"
    fi

    printf "\n"
    printf "After opening the editor (default: Nano) with the rebase plan:\n"
    printf "1. Change 'pick' to 'reword' (or 'r') for commits whose messages you want to change.\n"
    printf "   If you selected 'A specific commit by hash', you will see only that commit.\n"
    printf "   Change its command to 'reword' (or 'r').\n"
    printf "2. To pause the rebase operation at a specific commit (e.g., after a batch of changes,\n"
    printf "   or to inspect the state):\n"
    printf "   Locate the commit in your rebase plan where you want to pause and change its\n"
    printf "   command to 'edit' (or 'e').\n"
    printf "   For example, if you want to rewrite 15 commits, and then pause\n"
    printf "   before the 16th to review, change the 16th commit's command to 'edit'.\n"
    printf "   Git will stop at this 'edit' commit. This script will then give you options\n"
    printf "   to continue or abort.\n"
    printf "3. Save (Ctrl+O) and close (Ctrl+X) the rebase plan file in the editor (default: Nano).\n"
    printf "4. Git will sequentially open the editor (default: Nano) for each\n"
    printf "   'reword' commit. Rewrite the message, adhering to Conventional\n"
    printf "   Commits (https://www.conventionalcommits.org/en/v1.0.0/).\n"
    printf "   Example: feat(auth): add user login functionality\n"
    printf "   You will see the commit number and its old message in the editor window.\n"
    printf "5. Save (Ctrl+O) and close (Ctrl+X) each message file to proceed to the next commit.\n"
    printf "\n"
    read -r -p "Press Enter to continue and start interactive commit rewriting...\n"

    local REBASE_EDITOR # Stores the editor command to be used for rebase.
    REBASE_EDITOR=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")
    readonly REBASE_EDITOR # Ensure REBASE_EDITOR is immutable.

    GIT_SEQUENCE_EDITOR="$REBASE_EDITOR" git rebase -i "$rebase_command" # Initiates the interactive rebase with the chosen editor.

    handle_paused_rebase "$GIT_ROOT" # Calls function to handle any paused rebase operations.

    if [[ "$changes_stashed" = true ]]; then # Remind user to pop stashed changes if any were stashed.
        printf "\n"
        printf "Remember: You stashed changes before starting the script.\n"
        printf "Please restore them using 'git stash pop' after you are done.\n"
    fi

    printf "If you have successfully rewritten the commits, you may need to\n"
    printf "force push changes to the remote repository. Please check your Git\n"
    printf "history with 'git log --oneline' and, if necessary, execute\n"
    printf "'git push --force-with-lease'. Remember, this is only needed if you\n"
    printf "have already pushed these commits to a remote branch.\n"
}

# Check if the script is being run directly (not sourced).
# "$0" is the name of the script.
# "${BASH_SOURCE[0]}" is the path to the current script file, even if sourced.
# If they are the same, the script is being run directly, and main should be called.
[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "${@}"
