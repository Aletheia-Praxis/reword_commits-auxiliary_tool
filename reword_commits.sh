#!/bin/bash

display_help() {
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
    exit 0
}

get_rebase_option() {
    local choice=""
    while true; do
        read -r -p "Enter 1, 2 or 3: " choice
        if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
            echo "$choice"
            break
        else
            echo "Invalid choice. Please enter 1, 2 or 3." >&2
        fi
    done
}

get_num_commits() {
    local num_commits=""
    while true; do
        read -r -p "Enter the number of last commits you want to rewrite (e.g., 5 for the last 5 commits): " num_commits
        if [[ "$num_commits" =~ ^[0-9]+$ ]] && [ "$num_commits" -ne 0 ]; then
            echo "$num_commits"
            break
        else
            echo "Invalid input. Please enter a positive integer." >&2
        fi
    done
}

get_stash_choice() {
    local stash_choice=""
    while true; do
        read -r -p "Do you want to (s) stash changes and continue, or (e) exit? " stash_choice
        case "$stash_choice" in
            s|S)
                echo "s"
                break
                ;;
            e|E)
                echo "e"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 's' or 'e'." >&2
                ;;
        esac
    done
}

determine_git_editor() {
    local USE_DEFAULT_EDITOR="$1"
    local CUSTOM_EDITOR="$2"

    if [ "$USE_DEFAULT_EDITOR" = false ] && [ -n "$CUSTOM_EDITOR" ]; then
        echo "$CUSTOM_EDITOR"
    elif [ -n "$GIT_EDITOR" ]; then
        echo "$GIT_EDITOR"
    elif [ -n "$EDITOR" ]; then
        echo "$EDITOR"
    else
        echo "nano"
    fi
}

handle_paused_rebase() {
    local user_action=""
    while true; do
        if [ -d "$GIT_ROOT/.git/rebase-merge" ]; then
            echo ""
            echo "Git Rebase paused (likely on an 'edit' command or due to conflicts)."
            echo "Please check the status, resolve conflicts (if any), or review changes."
            git status
            echo ""
            read -r -p "Choose action: (c) - continue rebase, (a) - abort rebase, (q) - exit script: " user_action
            case "$user_action" in
                c|C)
                    git rebase --continue
                    if ! git rebase --continue; then
                        echo "Error continuing rebase. Please resolve conflicts manually or abort rebase." >&2
                    fi
                    ;;
                a|A)
                    git rebase --abort
                    echo "Git Rebase aborted."
                    exit 0
                    ;;
                q|Q)
                    echo "Exiting script. Git Rebase remains in a paused state."
                    exit 0
                    ;;
                *)
                    echo "Invalid input. Please enter 'c', 'a', or 'q'."
                    ;;
            esac
        else
            echo ""
            echo "Git Rebase operation completed."
            break
        fi
    done
}

main() {
    set -eo pipefail
    if [ "$#" -eq 0 ]; then
        display_help
    fi

    local CUSTOM_EDITOR=""
    local USE_DEFAULT_EDITOR=false

    while (( "$#" )); do
        case "$1" in
            -h|--help)
                display_help
                ;;
            -d|--default)
                USE_DEFAULT_EDITOR=true
                shift
                ;;
            --editor=*)
                CUSTOM_EDITOR="${1#*=}"
                shift
                ;;
            -e|--editor)
                if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                    CUSTOM_EDITOR="$2"
                    shift 2
                else
                    echo "Error: Missing argument for $1" >&2
                    exit 1
                fi
                ;;
            *)
                echo "Error: Invalid argument $1" >&2
                exit 1
                ;;
        esac
    done

    echo "Script for interactive rewriting of commit messages."
    echo "This script will use 'git rebase -i' to modify Git history."
    echo "Be careful, changing history can have consequences."
    echo ""

    local changes_stashed=false

    local GIT_ROOT
    GIT_ROOT=$(git rev-parse --show-toplevel)
    if [ -z "$GIT_ROOT" ]; then
        echo "Error: Could not find Git repository root directory." >&2
        exit 1
    fi

    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo ""
        echo "Warning: You have uncommitted changes or changes in the index." >&2
        local stash_choice
        stash_choice=$(get_stash_choice)
        case "$stash_choice" in
            s|S)
                echo "Stashing uncommitted changes..."
                if ! git stash push --include-untracked -m "Temporary stash on branch $(git rev-parse --abbrev-ref HEAD)"; then
                    echo "Error: Failed to stash changes. Please resolve the issue manually." >&2
                    exit 1
                fi
                changes_stashed=true
                ;;
            e|E)
                echo "Exiting script. Please commit or discard your changes manually."
                exit 0
                ;;
        esac
    fi

    echo "Do you want to rewrite history from the very first commit (root) or only the last N commits?"
    echo "1. From the first commit (root)"
    echo "2. Last N commits"
    echo "3. A specific commit by hash"

    local rebase_choice
    rebase_choice=$(get_rebase_option)

    local rebase_command=""

    if [ "$rebase_choice" == "1" ]; then
        rebase_command="--root"
        echo ""
        echo "Starting Git Rebase in interactive mode for all commits from the beginning..."
    elif [ "$rebase_choice" == "2" ]; then
        local num_commits
        num_commits=$(get_num_commits)
        rebase_command="HEAD~$num_commits"
        echo ""
        echo "Starting Git Rebase in interactive mode for the last ${num_commits} commits..."
    elif [ "$rebase_choice" == "3" ]; then
        read -r -p "Enter the full commit hash you want to reword: " commit_hash

        if [ -z "$commit_hash" ]; then
            echo "Commit hash cannot be empty." >&2
            exit 1
        fi

        if ! git cat-file -e "$commit_hash" 2>/dev/null; then
            echo "Error: Commit with hash '$commit_hash' does not exist in the repository."
            exit 1
        fi

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

    local REBASE_EDITOR
    REBASE_EDITOR=$(determine_git_editor "$USE_DEFAULT_EDITOR" "$CUSTOM_EDITOR")

    GIT_SEQUENCE_EDITOR="$REBASE_EDITOR" git rebase -i "$rebase_command"

    handle_paused_rebase

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

[[ "$0" == "${BASH_SOURCE[0]}" ]] && main "${@}"
