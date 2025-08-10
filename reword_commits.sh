#!/usr/bin/env bash

# Exit Codes:
# 0: Script executed successfully or exited gracefully (e.g., after displaying help, aborting rebase, or user choosing to exit).
# 1: General execution error occurred (e.g., failure during Git stash operation).
# 2: Invalid command-line argument, invalid user input, or environment error (e.g., not in a Git repository, missing argument for --editor).

# Function: display_help
# Description: Displays the help message for the script, detailing its usage,
#              available options, and examples.
# Arguments: None
# Exit Code: 0 (after displaying help and exiting)
display_help() {
    # basename "$0" extracts the script's name from its path (e.g., "reword_commits.sh").
    # This makes the usage message dynamic and correct regardless of how the script is called.
    printf "Usage: %s [OPTIONS]\n" "$(basename "$0")"
    printf "Script for interactively rewriting Git commit messages.\n"
    printf "\n"
    printf "Options:\n"
    printf "  -h, --help                        Show this help message and exit.\n"
    printf "  -d, --default                     Use default Git editor selection (GIT_EDITOR, EDITOR, then nano).\n"
    printf "  -e <EDITOR>, --editor=<EDITOR>    Specify the Git editor to use (e.g., nano, vim, code --wait).\n"
    printf "\n"
    printf "Examples:\n"
    printf "  %s\n" "$(basename "$0")"
    printf "  %s --help\n" "$(basename "$0")"
    printf "  %s --editor=vim\n" "$(basename "$0")"
    printf "  %s -e code --wait\n" "$(basename "$0")"
    printf "  %s --default\n" "$(basename "$0")"
    exit 0 # Exit the script after displaying help as requested.
}

# Function: get_rebase_option
# Description: Prompts the user to choose a rebase option (from root, last N commits, or specific commit)
#              and validates the input.
# Arguments: None
# Returns: The validated choice (1, 2, or 3)
get_rebase_option() {
    local choice="" # Declare 'choice' as a local variable to prevent it from leaking into the global scope.
    while true; do # Loop indefinitely until a valid choice is provided.
        read -r -p "Enter 1, 2 or 3: " choice # Prompt user for input. -r prevents backslash escapes.
        # Check if the choice is one of the valid options (1, 2, or 3).
        if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
            printf "%s\n" "$choice" # Output the valid choice to stdout.
            break # Exit the loop.
        else
            # Redirect error message to stderr (standard error) to keep stdout clean for script output.
            printf "%sInvalid choice. Please enter 1, 2 or 3.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2
        fi
    done
}

# Function: get_num_commits
# Description: Prompts the user to enter the number of last commits to rewrite
#              and validates that it's a positive integer.
# Arguments: None
# Returns: The validated number of commits.
get_num_commits() {
    local num_commits="" # Declare 'num_commits' as a local variable.
    while true; do # Loop indefinitely until valid input is received.
        read -r -p "Enter the number of last commits you want to rewrite (e.g., 5 for the last 5 commits): " num_commits
        # Check if input is a digit and greater than zero.
        # =~ ^[0-9]+$ checks if the variable contains only digits.
        # -ne 0 checks if the number is not zero.
        if [[ "$num_commits" =~ ^[0-9]+$ ]] && [[ "$num_commits" -ne 0 ]]; then
            printf "%s\n" "$num_commits" # Output the valid number.
            break # Exit the loop.
        else
            printf "%sInvalid input. Please enter a positive integer.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2 # Error to stderr.
        fi
    done
}

# Function: get_stash_choice
# Description: Prompts the user whether to stash uncommitted changes or exit the script.
# Arguments: None
# Returns: "s" for stash and continue, "e" for exit.
get_stash_choice() {
    local stash_choice="" # Declare 'stash_choice' as a local variable.
    while true; do # Loop until a valid choice.
        read -r -p "Do you want to (s) stash changes and continue, or (e) exit? " stash_choice
        case "$stash_choice" in
            s|S) # Case-insensitive match for 's'.
                printf "s\n" # Output choice.
                break # Exit loop.
                ;;
            e|E) # Case-insensitive match for 'e'.
                printf "e\n" # Output choice.
                break # Exit loop.
                ;;
            *) # Default case for invalid input.
                printf "%sInvalid choice. Please enter 's' or 'e'.%s\n" "${BOLD_YELLOW}" "${RESET}" >&2 # Error to stderr.
                ;;
        esac
    done
}

# Function: determine_git_editor
# Description: Determines which Git editor to use based on script arguments and environment variables.
# Arguments:
#   $1: USE_DEFAULT_EDITOR (boolean, true if --default flag is used)
#   $2: CUSTOM_EDITOR (string, value of -e or --editor argument)
# Returns: The determined editor command (e.g., "nano", "vim", "code --wait").
determine_git_editor() {
    local USE_DEFAULT_EDITOR="$1" # Local variable for clarity.
    local CUSTOM_EDITOR="$2" # Local variable for clarity.

    # If --default is not used AND a custom editor is provided via arguments, use it.
    if [[ "$USE_DEFAULT_EDITOR" = false ]] && [[ -n "$CUSTOM_EDITOR" ]]; then
        printf "%s\n" "$CUSTOM_EDITOR"
    # If GIT_EDITOR environment variable is set, use it. Git's preferred editor.
    elif [[ -n "$GIT_EDITOR" ]]; then
        printf "%s\n" "$GIT_EDITOR"
    # If EDITOR environment variable is set, use it. Generic editor for many programs.
    elif [[ -n "$EDITOR" ]]; then
        printf "%s\n" "$EDITOR"
    # Fallback to 'nano' if no custom editor, GIT_EDITOR, or EDITOR is defined.
    else
        printf "nano\n"
    fi
}

# Function: handle_paused_rebase
# Description: Checks if a Git rebase operation is paused (e.g., at an 'edit' step or due to conflicts).
#              If paused, it prompts the user to continue, abort, or exit the script,
#              and executes the chosen Git rebase command.
# Arguments:
#   $1: GIT_ROOT (path to the Git repository root)
# Exit Code: 0 (if user chooses to abort rebase or exit script)
handle_paused_rebase() {
    local user_action="" # Local variable to store user's choice.
    local GIT_ROOT="$1" # Declare GIT_ROOT as a local variable from the first argument.
    while true; do # Loop until rebase is completed or script exits.
        # Check for the existence of the rebase-merge directory within .git,
        # which indicates an ongoing/paused rebase operation.
        if [[ -d "$GIT_ROOT/.git/rebase-merge" ]]; then
            printf "\n"
            printf "Git Rebase paused (likely on an 'edit' command or due to conflicts).\n"
            printf "Please check the status, resolve conflicts (if any), or review changes.\n"
            git status # Show current Git status to help user identify issues.
            printf "\n"
            printf "If there are conflicts, resolve them, then stage the changes with 'git add <files>'.\n"
            read -r -p "Choose action: (c) - continue rebase, (a) - abort rebase, (q) - exit script: " user_action
            case "$user_action" in
                c|C) # User wants to continue rebase.
                    # Attempt to continue the rebase.
                    # The `if ! command; then ... fi` pattern is crucial for error handling,
                    # as `set -eo pipefail` would exit on failure otherwise,
                    # but here we want to provide a specific error message.
                    if ! git rebase --continue; then
                        printf "%sError continuing rebase. Please resolve conflicts manually or abort rebase.%s\n" "${BOLD_RED}" "${RESET}" >&2
                        # Do not exit here; allow the loop to re-prompt if continue fails.
                    fi
                    ;;
                a|A) # User wants to abort rebase.
                    git rebase --abort # Abort the rebase operation.
                    printf "Git Rebase aborted.\n"
                    exit 0 # Exit the script after aborting.
                    ;;
                q|Q) # User wants to quit the script, leaving rebase in paused state.
                    printf "Exiting script. Git Rebase remains in a paused state.\n"
                    exit 0 # Exit the script.
                    ;;
                *) # Invalid input.
                    printf "%sInvalid input. Please enter 'c', 'a', or 'q'.%s\n" "${BOLD_YELLOW}" "${RESET}"
                    ;;
            esac
        else
            printf "\n"
            printf "Git Rebase operation completed.\n"
            break # Exit loop if rebase-merge directory no longer exists (rebase finished).
        fi
    done
}

# Function: main
# Description: The main entry point of the script. It parses arguments, handles uncommitted changes,
#              prompts for rebase type, executes the interactive rebase, and provides post-rebase instructions.
# Arguments: All command-line arguments passed to the script.
main() {
    # set -eo pipefail:
    # -e: Exit immediately if a command exits with a non-zero status.
    # -o pipefail: The return value of a pipeline is the status of the last command
    #              to exit with a non-zero status, or zero if all commands exit
    #              successfully. This prevents errors in a pipe from being hidden.
    set -eo pipefail

    # If no arguments are provided to the script, display help and exit.
    # This ensures that running the script without any options will show usage information.
    if [[ "$#" -eq 0 ]]; then
        display_help
    fi

    local CUSTOM_EDITOR="" # Variable to store custom editor specified by user.
    local USE_DEFAULT_EDITOR=false # Flag to indicate if --default option is used.

    # Declare color variables as readonly local for use across functions, as they are constants.
    local BOLD_RED
    local BOLD_YELLOW
    local RESET

    # Check if tput is available and stdout is a TTY, and NO_COLOR is not set.
    # This ensures colors are used only when supported and desired.
    if command -v tput &>/dev/null && [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        BOLD_RED=$(tput setaf 1) # ANSI color code for red.
        BOLD_YELLOW=$(tput setaf 3) # ANSI color code for yellow.
        RESET=$(tput sgr0) # Resets text attributes to normal.
    else
        # If tput is not available, stdout is not a TTY, or NO_COLOR is set,
        # set color variables to empty strings to disable colors.
        BOLD_RED=""
        BOLD_YELLOW=""
        RESET=""
    fi

    # Argument parsing loop. "$#" is the number of arguments, loops while it's greater than 0.
    # This loop processes each command-line argument to configure script behavior.
    while (( "$#" )); do
        case "$1" in # $1 is the current argument.
            -h|--help) # Help option: Displays usage information and exits.
                display_help # Call function to display help and exit.
                ;;
            -d|--default) # Default editor option: Instructs the script to use Git's default editor selection logic.
                USE_DEFAULT_EDITOR=true # Set flag to true.
                shift # Move to the next argument.
                ;;
            --editor=*) # Long option for editor with assignment (e.g., --editor=vim): Specifies a custom Git editor directly.
                CUSTOM_EDITOR="${1#*=}" # Extract value after "=".
                shift # Move to the next argument.
                ;;
            -e|--editor) # Short or long option for editor requiring a separate argument: Specifies a custom Git editor that follows the option.
                # Check if the next argument ($2) exists and doesn't start with a hyphen (another option).
                if [[ -n "$2" ]] && [[ "${2:0:1}" != "-" ]]; then
                    CUSTOM_EDITOR="$2" # Assign the next argument as the custom editor.
                    shift 2 # Consume both the option and its value.
                else
                    printf "%sError: Missing argument for %s%s\n" "${BOLD_RED}" "$1" "${RESET}" >&2 # Error if value is missing.
                    exit 2 # Exit with error (exit code 2 for command-line syntax errors, as per best practices).
                fi
                ;;
            *) # Catch-all for invalid arguments: Reports an unknown argument and exits with an error.
                printf "%sError: Invalid argument %s%s\n" "${BOLD_RED}" "$1" "${RESET}" >&2 # Report invalid argument.
                exit 2 # Exit with error (exit code 2 for command-line syntax errors).
                ;;
        esac
    done

    printf "Script for interactive rewriting of commit messages.\n"
    printf "This script will use 'git rebase -i' to modify Git history.\n"
    printf "Be careful, changing history can have consequences.\n"
    printf "\n"

    local changes_stashed=false # Flag to track if changes were stashed.

    # Declare GIT_ROOT as a local variable. Its value is determined by `git rev-parse --show-toplevel`,
    # which finds the root directory of the current Git repository.
    local GIT_ROOT
    GIT_ROOT=$(git rev-parse --show-toplevel)
    # Mark GIT_ROOT as readonly to ensure its immutability after initialization.
    readonly GIT_ROOT
    if [[ -z "$GIT_ROOT" ]]; then # Check if GIT_ROOT is empty, indicating not in a Git repo.
        printf "%sError: Could not find Git repository root directory.%s\n" "${BOLD_RED}" "${RESET}" >&2
        exit 2 # Changed to exit 2 for misuse/environment error.
    fi

    # Check for uncommitted changes in the working directory or staged area.
    # This is a critical check to prevent data loss during rebase operations.
    # git diff --quiet: Exits with 1 if there are changes, 0 if clean.
    # git diff --cached --quiet: Checks staged changes.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        printf "\n"
        printf "%sWarning: You have uncommitted changes or changes in the index.\n" "${BOLD_YELLOW}"
        printf "         Please commit or stash them before proceeding.%s\n" "${RESET}" >&2
        local stash_choice # Local variable for user's stash choice.
        stash_choice=$(get_stash_choice) # Get choice from helper function.
        case "$stash_choice" in
            s|S) # User chose to stash: Stashes current changes to allow rebase to proceed cleanly.
                printf "Stashing uncommitted changes...\n"
                # git stash push --include-untracked: Stashes changes, including untracked files.
                # -m: Adds a message to the stash entry for easier identification.
                # $(git rev-parse --abbrev-ref HEAD): Gets the current branch name.
                if ! git stash push --include-untracked -m "Temporary stash on branch $(git rev-parse --abbrev-ref HEAD)"; then
                    printf "%sError: Failed to stash changes. Please resolve the issue manually and try again.%s\n" "${BOLD_RED}" "${RESET}" >&2
                    exit 1 # Exit if stashing fails. This is a runtime error, not misuse.
                fi
                changes_stashed=true # Set flag to true to remind user to pop stash later.
                ;;
            e|E) # User chose to exit: Script terminates without performing any rebase.
                printf "Exiting script. Please commit or discard your changes manually.\n"
                exit 0 # Exit the script.
                ;;
        esac
    fi

    printf "Do you want to rewrite history from the very first commit (root) or only the last N commits?\n"
    printf "1. From the first commit (root): Rewrites all commits from the initial commit.\n"
    printf "2. Last N commits: Rewrites a specified number of recent commits.\n"
    printf "3. A specific commit by hash: Rewrites a single commit by its hash, \n"
    printf "   allowing for targeted message changes.\n"

    local rebase_choice # Local variable for rebase choice.
    rebase_choice=$(get_rebase_option) # Get rebase choice from helper function.

    local rebase_command="" # Variable to store the argument for git rebase -i.

    if [[ "$rebase_choice" == "1" ]]; then
        rebase_command="--root" # --root rebases all commits from the beginning.
        printf "\n"
        printf "Starting Git Rebase in interactive mode for all commits from the beginning...\n"
    elif [[ "$rebase_choice" == "2" ]]; then
        local num_commits # Local variable for number of commits.
        num_commits=$(get_num_commits) # Get number of commits from helper function.
        # HEAD~$num_commits specifies the last N commits relative to HEAD.
        rebase_command="HEAD~""$num_commits"
        printf "\n"
        printf "Starting Git Rebase in interactive mode for the last %s commits...\n" "$num_commits"
    elif [[ "$rebase_choice" == "3" ]]; then
        local commit_hash # Local variable for commit hash.
        read -r -p "Enter the full or abbreviated commit hash you want to reword (e.g., 110a32b for abbreviated or full hash): " commit_hash
        
        if [[ -z "$commit_hash" ]]; then # Check if commit hash is empty.
            printf "%sError: Commit hash cannot be empty.%s\n" "${BOLD_RED}" "${RESET}" >&2
            exit 2 # Exit with error (exit code 2 for invalid input).
        fi

        # Validate commit hash format: 7 or 40 hexadecimal characters.
        # This regex ensures the input is a valid SHA-1 hash, improving robustness.
        if ! [[ "$commit_hash" =~ ^([0-9a-fA-F]{7}|[0-9a-fA-F]{40})$ ]]; then
            printf "%sError: Invalid commit hash format. Must be a 7-character abbreviated or 40-character full hexadecimal string.%s\n" "${BOLD_RED}" "${RESET}" >&2
            exit 2 # Exit with error for invalid format.
        fi

        # Attempt to resolve abbreviated hash to full hash to ensure uniqueness.
        # This is crucial for handling abbreviated hashes correctly and preventing ambiguity.
        local full_commit_hash
        full_commit_hash=$(git rev-parse --verify "$commit_hash" 2>/dev/null)

        if [[ -z "$full_commit_hash" ]]; then
            printf "%sError: Commit with hash '%s' does not exist in the repository or is ambiguous.%s\n" "${BOLD_RED}" "${RESET}" "$commit_hash"
            exit 2 # Exit with error (exit code 2 for invalid input).
        fi

        commit_hash="$full_commit_hash" # Use the full commit hash for rebase.

        # git cat-file -e: Checks if a Git object (commit, tree, blob) exists.
        # 2>/dev/null: Suppress error output from git cat-file if commit doesn't exist.
        if ! git cat-file -e "$commit_hash" 2>/dev/null; then
            printf "%sError: Commit with hash '%s' does not exist in the repository.%s\n" "${BOLD_RED}" "${RESET}" "$commit_hash"
            exit 2 # Exit with error (exit code 2 for invalid input).
        fi

        # For reword, we rebase on the parent of the commit to be reworded.
        rebase_command="%s~1" "$commit_hash"
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

    # Declare REBASE_EDITOR as a local variable. Its value is determined by the `determine_git_editor` function.
    local REBASE_EDITOR
    REBASE_EDITOR=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR") # Determine the editor to use for rebase.
    # Mark REBASE_EDITOR as readonly to ensure its immutability after initialization.
    readonly REBASE_EDITOR

    # GIT_SEQUENCE_EDITOR: Environment variable that specifies the editor Git will use for interactive rebase.
    # This ensures that the determined editor is used for the rebase plan and individual commit messages.
    # git rebase -i "$rebase_command": Starts the interactive rebase.
    GIT_SEQUENCE_EDITOR="$REBASE_EDITOR" git rebase -i "$rebase_command"

    # Call handle_paused_rebase after the initial rebase command, in case it pauses for 'edit' or conflicts.
    handle_paused_rebase "$GIT_ROOT"

    # If changes were stashed at the beginning, remind the user to pop them.
    # This helps in restoring the working directory to its state before the script execution.
    if [[ "$changes_stashed" = true ]]; then
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
