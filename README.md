# Git Commit Reword Tool

This script provides an interactive way to rewrite Git commit messages using `git rebase -i`. It simplifies the process of modifying your commit history, making it easier to adhere to conventions like Conventional Commits.

## Purpose

The main goal of this script is to offer a user-friendly interface for an otherwise complex Git operation: interactively rebasing commits to change their messages. It guides the user through the process, from selecting which commits to reword to handling potential pauses during the rebase.

## Prerequisites

*   Git installed on your system.
*   A basic understanding of Git commands.

## Options

*   `-h`, `--help`: Show the help message and exit.
*   `-d`, `--default`: Use default Git editor selection (checks `GIT_EDITOR`, then `EDITOR`, then falls back to `nano`).
*   `-e <EDITOR>`, `--editor=<EDITOR>`: Specify the Git editor to use (e.g., `nano`, `vim`, `code --wait`).

## Functionality

The script performs the following key functions:

1.  **Handle Uncommitted Changes**: Detects if there are uncommitted changes and prompts the user to either stash them temporarily or exit the script.
2.  **Select Rebase Scope**: Allows the user to choose whether to reword commits from:
    *   The very first commit (root).
    *   The last N commits.
    *   A specific commit by its hash.
3.  **Interactive Rebasing**: Initiates `git rebase -i` with the chosen scope.
4.  **Guidance for Editor**: Provides clear instructions on how to use the interactive rebase editor (defaulting to Nano if `GIT_EDITOR` or `EDITOR` are not set, or using the specified editor):
    *   How to change `pick` to `reword` (or `r`).
    *   How to use `edit` (or `e`) to pause the rebase at a specific commit for inspection, conflict resolution, or making additional changes.
    *   Instructions for saving and closing editor files.
5.  **Conventional Commits Reminder**: Reminds users to follow Conventional Commits guidelines when rewriting messages.
6.  **Rebase Pause Handling**: Detects if `git rebase` has paused (e.g., due to an `edit` command or conflicts) and offers options to `continue`, `abort`, or `exit` the script while leaving the rebase in a paused state.
7.  **Post-Rebase Instructions**: After successful rebase, it reminds the user to force push changes to the remote repository if necessary and to check their Git history.

## How to Use

1.  **Save the Script**: Save the script content into a file named `reword_commits.sh` (or any preferred name) in your Git repository.
2.  **Make it Executable**: Open your terminal, navigate to the script's directory, and make it executable:
    ```bash
    chmod +x reword_commits.sh
    ```
3.  **Run the Script**: Execute the script from your terminal within your Git repository, optionally specifying an editor:
    ```bash
    ./reword_commits.sh
    ./reword_commits.sh --editor=vim
    ./reword_commits.sh -e code --wait
    ./reword_commits.sh --default
    ```
4.  **Handle Uncommitted Changes (if prompted)**: If you have uncommitted changes, the script will prompt you to `(s) stash` them or `(e) exit`. Choose `s` to temporarily save your changes and proceed, or `e` to exit and handle them manually.
5.  **Choose Rebase Option**: Follow the on-screen prompts to select how you want to rewrite your history:
    *   Enter `1` to reword commits from the first commit (root).
    *   Enter `2` to reword the last N commits (you'll be asked for the number).
    *   Enter `3` to reword a specific commit by its full hash (you'll be asked for the commit hash).
6.  **Interactive Editor Instructions**: Carefully read the on-screen instructions before pressing Enter. These instructions explain how to modify the rebase plan in your default text editor (e.g., Nano, Vim, VS Code).
    *   To modify a commit message, change `pick` to `reword` (or `r`) next to the commit hash.
    *   To pause the rebase at a specific commit for inspection, conflict resolution, or making additional changes, change `pick` to `edit` (or `e`). If you choose this, the script will pause and provide options to continue or abort.
7.  **Rewrite Commit Messages**: For each commit you marked `reword`, your configured editor will open. Change the commit message as desired, adhering to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standards (e.g., `feat(scope): descriptive message`). Save and close the editor file to proceed to the next commit or complete the rebase.
8.  **Handle Pauses (if any)**: If the rebase pauses (e.g., due to an `edit` command or merge conflicts), the script will prompt you to:
    *   Enter `c` to continue the rebase (after resolving any conflicts manually and staging the changes).
    *   Enter `a` to abort the rebase, discarding all changes made during the rebase process.
    *   Enter `q` to exit the script, leaving the rebase in a paused state for manual intervention.
9.  **Restore Stashed Changes (if applicable)**: If you stashed changes at the beginning of the process, the script will remind you to restore them using `git stash pop` after the rebase is successfully completed.
10. **Force Push (if needed)**: After the rebase completes, if you have pushed these commits to a remote repository previously, you **must** force push your changes. Always check your Git history first with `git log --oneline` before force pushing:
    ```bash
    git push --force-with-lease
    ```

## Troubleshooting

*   **Rebase Conflicts**: If `git rebase` encounters conflicts, resolve them manually, `git add` the resolved files, and then choose `c` (continue) when prompted by the script.
*   **Editor Issues**: Ensure your specified editor (with `--editor`) is correctly configured and accessible in your PATH. If using `code --wait` for VS Code, ensure the `code` command is available.
*   **Script Exited Unexpectedly**: If the script exits and leaves Git in a rebase state, you can manually `git rebase --continue`, `git rebase --abort`, or `git rebase --quit` to resolve it.

## Important Notes

*   **Caution with History Rewriting**: Rewriting Git history can have significant consequences, especially if you are working on a shared branch. Always ensure you understand the implications before proceeding, as it changes the commit IDs for the rewritten commits.
*   **Backup**: Consider backing up your branch or repository before performing extensive history rewriting. You can create a new branch as a backup using `git branch <backup-branch-name>`.
*   **Conventional Commits**: It is highly recommended to follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for clear, consistent, and automated changelog generation.
