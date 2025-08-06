#!/usr/bin/env bash

# Function: display_help
# Description: Displays the help message for the script, detailing its usage,
#              available options, and examples.
# Arguments: None
# Exit Code: 0 (after displaying help and exiting)
display_help() {
    # basename "$0" extracts the script's name from its path (e.g., "reword_commits.sh").
    # This makes the usage message dynamic and correct regardless of how the script is called.
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Script for interactively rewriting Git commit messages."
    echo ""
    echo "Options:"
    echo "  -h, --help                      Show this help message and exit."
    echo "  -d, --default                   Use default Git editor selection (GIT_EDITOR, EDITOR, then nano)."
    echo "  -e <EDITOR>, --editor=<EDITOR>  Specify the Git editor to use (e.g., nano, vim, code --wait)."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")"
    echo "  $(basename "$0") --help"
    echo "  $(basename "$0") --editor=vim"
    echo "  $(basename "$0") -e code --wait"
    echo "  $(basename "$0") --default"
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
            echo "$choice" # Output the valid choice to stdout.
            break # Exit the loop.
        else
            # Redirect error message to stderr (standard error) to keep stdout clean for script output.
            echo "Invalid choice. Please enter 1, 2 or 3." >&2
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
        if [[ "$num_commits" =~ ^[0-9]+$ ]] && [ "$num_commits" -ne 0 ]; then
            echo "$num_commits" # Output the valid number.
            break # Exit the loop.
        else
            echo "Invalid input. Please enter a positive integer." >&2 # Error to stderr.
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
                echo "s" # Output choice.
                break # Exit loop.
                ;;
            e|E) # Case-insensitive match for 'e'.
                echo "e" # Output choice.
                break # Exit loop.
                ;;
            *) # Default case for invalid input.
                echo "Invalid choice. Please enter 's' or 'e'." >&2 # Error to stderr.
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
    if [ "$USE_DEFAULT_EDITOR" = false ] && [ -n "$CUSTOM_EDITOR" ]; then
        echo "$CUSTOM_EDITOR"
    # If GIT_EDITOR environment variable is set, use it. Git's preferred editor.
    elif [ -n "$GIT_EDITOR" ]; then
        echo "$GIT_EDITOR"
    # If EDITOR environment variable is set, use it. Generic editor for many programs.
    elif [ -n "$EDITOR" ]; then
        echo "$EDITOR"
    # Fallback to 'nano' if no custom editor, GIT_EDITOR, or EDITOR is defined.
    else
        echo "nano"
    fi
}

# Function: handle_paused_rebase
# Description: Checks if a Git rebase operation is paused (e.g., at an 'edit' step or due to conflicts).
#              If paused, it prompts the user to continue, abort, or exit the script,
#              and executes the chosen Git rebase command.
# Arguments: None
# Global Variables Used: GIT_ROOT (expected to be set by main)
# Exit Code: 0 (if user chooses to abort rebase or exit script)
handle_paused_rebase() {
    local user_action="" # Local variable to store user's choice.
    while true; do # Loop until rebase is completed or script exits.
        # Check for the existence of the rebase-merge directory within .git,
        # which indicates an ongoing/paused rebase operation.
        if [ -d "$GIT_ROOT/.git/rebase-merge" ]; then
            echo ""
            echo "Git Rebase paused (likely on an 'edit' command or due to conflicts)."
            echo "Please check the status, resolve conflicts (if any), or review changes."
            git status # Show current Git status to help user identify issues.
            echo ""
            read -r -p "Choose action: (c) - continue rebase, (a) - abort rebase, (q) - exit script: " user_action
            case "$user_action" in
                c|C) # User wants to continue rebase.
                    # Attempt to continue the rebase.
                    # The `if ! command; then ... fi` pattern is crucial for error handling,
                    # as `set -eo pipefail` would exit on failure otherwise,
                    # but here we want to provide a specific error message.
                    if ! git rebase --continue; then
                        echo "Error continuing rebase. Please resolve conflicts manually or abort rebase." >&2
                        # Do not exit here; allow the loop to re-prompt if continue fails.
                    fi
                    ;;
                a|A) # User wants to abort rebase.
                    git rebase --abort # Abort the rebase operation.
                    echo "Git Rebase aborted."
                    exit 0 # Exit the script after aborting.
                    ;;
                q|Q) # User wants to quit the script, leaving rebase in paused state.
                    echo "Exiting script. Git Rebase remains in a paused state."
                    exit 0 # Exit the script.
                    ;;
                *) # Invalid input.
                    echo "Invalid input. Please enter 'c', 'a', or 'q'."
                    ;;
            esac
        else
            echo ""
            echo "Git Rebase operation completed."
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
    if [ "$#" -eq 0 ]; then
        display_help
    fi

    local CUSTOM_EDITOR="" # Variable to store custom editor specified by user.
    local USE_DEFAULT_EDITOR=false # Flag to indicate if --default option is used.

    # Argument parsing loop. "$#" is the number of arguments, loops while it's greater than 0.
    while (( "$#" )); do
        case "$1" in # $1 is the current argument.
            -h|--help) # Help option.
                display_help # Call function to display help and exit.
                ;;
            -d|--default) # Default editor option.
                USE_DEFAULT_EDITOR=true # Set flag to true.
                shift # Move to the next argument.
                ;;
            --editor=*) # Long option for editor with assignment (e.g., --editor=vim).
                CUSTOM_EDITOR="${1#*=}" # Extract value after "=".
                shift # Move to the next argument.
                ;;
            -e|--editor) # Short or long option for editor requiring a separate argument.
                # Check if the next argument ($2) exists and doesn't start with a hyphen (another option).
                if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                    CUSTOM_EDITOR="$2" # Assign the next argument as the custom editor.
                    shift 2 # Consume both the option and its value.
                else
                    echo "Error: Missing argument for $1" >&2 # Error if value is missing.
                    exit 1 # Exit with error.
                fi
                ;;
            *) # Catch-all for invalid arguments.
                echo "Error: Invalid argument $1" >&2 # Report invalid argument.
                exit 1 # Exit with error.
                ;;
        esac
    done

    echo "Script for interactive rewriting of commit messages."
    echo "This script will use 'git rebase -i' to modify Git history."
    echo "Be careful, changing history can have consequences."
    echo ""

    local changes_stashed=false # Flag to track if changes were stashed.

    # Declare GIT_ROOT as a local variable. Its value is determined by `git rev-parse --show-toplevel`,
    # which finds the root directory of the current Git repository.
    local GIT_ROOT
    GIT_ROOT=$(git rev-parse --show-toplevel)
    # Mark GIT_ROOT as readonly to ensure its immutability after initialization.
    readonly GIT_ROOT
    if [ -z "$GIT_ROOT" ]; then # Check if GIT_ROOT is empty, indicating not in a Git repo.
        echo "Error: Could not find Git repository root directory." >&2
        exit 1
    fi

    # Check for uncommitted changes in the working directory or staged area.
    # git diff --quiet: Exits with 1 if there are changes, 0 if clean.
    # git diff --cached --quiet: Checks staged changes.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo ""
        echo "Warning: You have uncommitted changes or changes in the index." >&2
        local stash_choice # Local variable for user's stash choice.
        stash_choice=$(get_stash_choice) # Get choice from helper function.
        case "$stash_choice" in
            s|S) # User chose to stash.
                echo "Stashing uncommitted changes..."
                # git stash push --include-untracked: Stashes changes, including untracked files.
                # -m: Adds a message to the stash entry for easier identification.
                # $(git rev-parse --abbrev-ref HEAD): Gets the current branch name.
                if ! git stash push --include-untracked -m "Temporary stash on branch $(git rev-parse --abbrev-ref HEAD)"; then
                    echo "Error: Failed to stash changes. Please resolve the issue manually." >&2
                    exit 1 # Exit if stashing fails.
                fi
                changes_stashed=true # Set flag to true to remind user to pop stash later.
                ;;
            e|E) # User chose to exit.
                echo "Exiting script. Please commit or discard your changes manually."
                exit 0 # Exit the script.
                ;;
        esac
    fi

    echo "Do you want to rewrite history from the very first commit (root) or only the last N commits?"
    echo "1. From the first commit (root)"
    echo "2. Last N commits"
    echo "3. A specific commit by hash"

    local rebase_choice # Local variable for rebase choice.
    rebase_choice=$(get_rebase_option) # Get rebase choice from helper function.

    local rebase_command="" # Variable to store the argument for git rebase -i.

    if [ "$rebase_choice" == "1" ]; then
        rebase_command="--root" # --root rebases all commits from the beginning.
        echo ""
        echo "Starting Git Rebase in interactive mode for all commits from the beginning..."
    elif [ "$rebase_choice" == "2" ]; then
        local num_commits # Local variable for number of commits.
        num_commits=$(get_num_commits) # Get number of commits from helper function.
        # HEAD~$num_commits specifies the last N commits relative to HEAD.
        rebase_command="HEAD~$num_commits"
        echo ""
        echo "Starting Git Rebase in interactive mode for the last ${num_commits} commits..."
    elif [ "$rebase_choice" == "3" ]; then
        local commit_hash # Local variable for commit hash.
        read -r -p "Enter the full commit hash you want to reword: " commit_hash

        if [ -z "$commit_hash" ]; then # Check if commit hash is empty.
            echo "Commit hash cannot be empty." >&2
            exit 1
        fi

        # git cat-file -e: Checks if a Git object (commit, tree, blob) exists.
        # 2>/dev/null: Suppress error output from git cat-file if commit doesn't exist.
        if ! git cat-file -e "$commit_hash" 2>/dev/null; then
            echo "Error: Commit with hash '$commit_hash' does not exist in the repository."
            exit 1
        fi

        # For reword, we rebase on the parent of the commit to be reworded.
        rebase_command="$commit_hash~1"
        echo ""
        echo "Starting Git Rebase in interactive mode to reword commit '$commit_hash'..."
    fi

    echo ""
    echo "After opening the editor (default: Nano) with the rebase plan:"
    echo "1. Change 'pick' to 'reword' (or 'r') for commits whose messages you want to change."
    echo "   If you selected 'A specific commit by hash', you will see only that commit."
    echo "   Change its command to 'reword' (or 'r')."
    echo "2. To pause the rebase operation at a specific commit (e.g., after a batch of changes,"
    echo "   or to inspect the state):"
    echo "   Locate the commit in your rebase plan where you want to pause and change its"
    echo "   command to 'edit' (or 'e')."
    echo "   For example, if you want to rewrite 15 commits, and then pause"
    echo "   before the 16th to review, change the 16th commit's command to 'edit'."
    echo "   Git will stop at this 'edit' commit. This script will then give you options"
    echo "   to continue or abort."
    echo "3. Save (Ctrl+O) and close (Ctrl+X) the rebase plan file in the editor (default: Nano)."
    echo "4. Git will sequentially open the editor (default: Nano) for each"
    echo "   'reword' commit. Rewrite the message, adhering to Conventional"
    echo "   Commits (https://www.conventionalcommits.org/en/v1.0.0/)."
    echo "   Example: feat(auth): add user login functionality"
    echo "   You will see the commit number and its old message in the editor window."
    echo "5. Save (Ctrl+O) and close (Ctrl+X) each message file to proceed to the next commit."
    echo ""
    read -r -p "Press Enter to continue and start interactive commit rewriting..."

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
    handle_paused_rebase

    # If changes were stashed at the beginning, remind the user to pop them.
    if [ "$changes_stashed" = true ]; then
        echo ""
        echo "Remember: You stashed changes before starting the script."
        echo "Please restore them using 'git stash pop' after you are done."
    fi

    echo "If you have successfully rewritten the commits, you may need to"
    echo "force push changes to the remote repository. Please check your Git"
    echo "history with 'git log --oneline' and, if necessary, execute"
    echo "'git push --force-with-lease'."
}

# Check if the script is being run directly (not sourced).
# "$0" is the name of the script.
# "${BASH_SOURCE[0]}" is the path to the current script file, even if sourced.
# If they are the same, the script is being run directly, and main should be called.
[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "${@}"
