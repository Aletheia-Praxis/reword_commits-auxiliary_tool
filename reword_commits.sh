#!/bin/bash

echo "Script for interactive rewriting of commit messages."
echo "This script will use 'git rebase -i' to modify Git history."
echo "Be careful, changing history can have consequences."
echo ""

GIT_ROOT=$(git rev-parse --show-toplevel)
if [ -z "$GIT_ROOT" ]; then
    echo "Error: Could not find Git repository root directory."
    exit 1
fi

echo "Do you want to rewrite history from the very first commit (root) or only the last N commits?"
echo "1. From the first commit (root)"
echo "2. Last N commits"
echo "3. A specific commit by hash"

rebase_choice=""
while true; do
    read -p "Enter 1, 2 or 3: " rebase_choice
    if [ "$rebase_choice" == "1" ] || [ "$rebase_choice" == "2" ] || [ "$rebase_choice" == "3" ]; then
        break
    else
        echo "Invalid choice. Please enter 1, 2 or 3."
    fi
done

rebase_command=""

if [ "$rebase_choice" == "1" ]; then
    rebase_command="--root"
    echo ""
    echo "Starting Git Rebase in interactive mode for all commits from the beginning..."
elif [ "$rebase_choice" == "2" ]; then
    num_commits=""
    while true; do
        read -p "Enter the number of last commits you want to rewrite (e.g., 5 for the last 5 commits): " num_commits
        if [[ "$num_commits" =~ ^[0-9]+$ ]] && [ "$num_commits" -ne 0 ]; then
            break
        else
            echo "Invalid input. Please enter a positive integer."
        fi
    done
    rebase_command="HEAD~"$num_commits
    echo ""
    echo "Starting Git Rebase in interactive mode for the last "$num_commits" commits..."
elif [ "$rebase_choice" == "3" ]; then
    read -p "Enter the full commit hash you want to reword: " commit_hash

    if [ -z "$commit_hash" ]; then
        echo "Commit hash cannot be empty."
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
echo "   If you selected 'A specific commit by hash', you will see only that commit. Change its command to 'reword' (or 'r')."
echo "2. To pause the rebase operation at a specific commit (e.g., after a batch of changes, or to inspect the state):"
echo "   Locate the commit in your rebase plan where you want to pause and change its command to 'edit' (or 'e')."
echo "   For example, if you want to rewrite 15 commits, and then pause before the 16th to review, change the 16th commit's command to 'edit'."
echo "   Git will stop at this 'edit' commit. This script will then give you options to continue or abort."
echo "3. Save (Ctrl+O) and close (Ctrl+X) the rebase plan file in the editor (default: Nano)."
echo "4. Git will sequentially open the editor (default: Nano) for each 'reword' commit. Rewrite the message, adhering to Conventional Commits (https://www.conventionalcommits.org/en/v1.0.0/)."
echo "   Example: feat(auth): add user login functionality"
echo "   You will see the commit number and its old message in the editor window."
echo "5. Save (Ctrl+O) and close (Ctrl+X) each message file to proceed to the next commit."
echo ""
read -p "Press Enter to continue and start interactive commit rewriting..."

if [ -n "$GIT_EDITOR" ]; then
    REBASE_EDITOR="$GIT_EDITOR"
elif [ -n "$EDITOR" ]; then
    REBASE_EDITOR="$EDITOR"
else
    REBASE_EDITOR="nano"
fi

GIT_SEQUENCE_EDITOR="$REBASE_EDITOR" git rebase -i "$rebase_command"

while true; do
    if [ -d "$GIT_ROOT/.git/rebase-merge" ]; then
        echo ""
        echo "Git Rebase paused (likely on an 'edit' command or due to conflicts)."
        echo "Please check the status, resolve conflicts (if any), or review changes."
        git status
        echo ""
        read -p "Choose action: (c) - continue rebase, (a) - abort rebase, (q) - exit script: " user_action
        case "$user_action" in
            c|C)
                git rebase --continue
                if [ $? -ne 0 ]; then
                    echo "Error continuing rebase. Please resolve conflicts manually or abort rebase."
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

echo "If you have successfully rewritten the commits, you may need to force push changes to the remote repository:"
echo "git push --force-with-lease"
echo ""
echo "Please check your Git history with 'git log --oneline' and, if necessary, execute 'git push --force-with-lease'."