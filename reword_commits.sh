#!/bin/bash

echo "Script for interactive rewriting of commit messages."
echo "This script will use 'git rebase -i' to modify Git history."
echo "Be careful, changing history can have consequences."
echo "Remember '--force-with-lease'."
echo ""

GIT_ROOT=$(git rev-parse --show-toplevel)
if [ -z "$GIT_ROOT" ]; then
    echo "Error: Could not find Git repository root directory."
    exit 1
fi

echo "Do you want to rewrite history from the very first commit (root) or only the last N commits?"
echo "1. From the first commit (root)"
echo "2. Last N commits"
read -p "Enter 1 or 2: " rebase_choice

rebase_command=""

if [ "$rebase_choice" == "1" ]; then
    rebase_command="--root"
    echo ""
    echo "Starting Git Rebase in interactive mode for all commits from the beginning..."
elif [ "$rebase_choice" == "2" ]; then
    read -p "Enter the number of last commits you want to rewrite (e.g., 5 for the last 5 commits): " num_commits

    if ! [[ "$num_commits" =~ ^[0-9]+$ ]] || [ "$num_commits" -eq 0 ]; then
        echo "Invalid input. Please enter a positive integer."
        exit 1
    fi
    rebase_command="HEAD~$num_commits"
    echo ""
    echo "Starting Git Rebase in interactive mode for the last $num_commits commits..."
else
    echo "Invalid choice. Please enter 1 or 2."
    exit 1
fi

echo ""
echo "After opening the editor (Nano) with the rebase plan:"
echo "1. Change 'pick' to 'reword' (or 'r') for commits whose messages you want to change."
echo "2. To pause after each batch (e.g., 15 commits):"
echo "   Find the 16th commit in your current batch and change its command to 'edit' (or 'e')."
echo "   Git will stop at this commit, and the script will give you a choice."
echo "3. Save (Ctrl+O) and close (Ctrl+X) the rebase plan file."
echo "4. Git will sequentially open the editor (Nano) for each 'reword' commit. Rewrite the message, adhering to Conventional Commits."
echo "   Example: feat(auth): add user login functionality"
echo "   You will see the commit number and its old message in the editor window."
echo "5. Save (Ctrl+O) and close (Ctrl+X) each message file to proceed to the next commit."
echo ""
read -p "Press Enter to continue and start interactive commit rewriting..."

GIT_SEQUENCE_EDITOR=nano git rebase -i "$rebase_command"

while true; do
    if [ -d "$GIT_ROOT/.git/rebase-merge" ]; then
        echo ""
        echo "Git Rebase paused (likely on an 'edit' command or due to conflicts)."
        echo "Please check the status, resolve conflicts (if any), or review changes."
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