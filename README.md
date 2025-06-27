# Git Commit Reword Tool

This script provides an interactive way to rewrite Git commit messages using `git rebase -i`. It simplifies the process of modifying your commit history, making it easier to adhere to conventions like Conventional Commits.

## Purpose

The main goal of this script is to offer a user-friendly interface for an otherwise complex Git operation: interactively rebasing commits to change their messages. It guides the user through the process, from selecting which commits to reword to handling potential pauses during the rebase.

## Functionality

The script performs the following key functions:

1.  **Select Rebase Scope**: Allows the user to choose whether to reword commits from:
    *   The very first commit (root).
    *   The last N commits.
    *   A specific commit by its hash.
2.  **Interactive Rebasing**: Initiates `git rebase -i` with the chosen scope.
3.  **Guidance for Editor**: Provides clear instructions on how to use the interactive rebase editor (defaulting to Nano if `GIT_EDITOR` or `EDITOR` are not set):
    *   How to change `pick` to `reword` (or `r`).
    *   How to use `edit` (or `e`) to pause the rebase at a specific commit for inspection or conflict resolution.
    *   Instructions for saving and closing editor files.
4.  **Conventional Commits Reminder**: Reminds users to follow Conventional Commits guidelines when rewriting messages.
5.  **Rebase Pause Handling**: Detects if `git rebase` has paused (e.g., due to an `edit` command or conflicts) and offers options to `continue`, `abort`, or `exit` the script while leaving the rebase in a paused state.
6.  **Post-Rebase Instructions**: After successful rebase, it reminds the user to force push changes to the remote repository if necessary and to check their Git history.

## How to Use

1.  **Save the Script**: Save the script content into a file named `reword_commits.sh` (or any preferred name) in your Git repository.
2.  **Make it Executable**: Open your terminal, navigate to the script's directory, and make it executable:
    ```bash
    chmod +x reword_commits.sh
    ```
3.  **Run the Script**: Execute the script from your terminal within your Git repository:
    ```bash
    ./reword_commits.sh
    ```
4.  **Choose Rebase Option**: Follow the prompts to select how you want to rewrite your history:
    *   `1`: From the first commit.
    *   `2`: For the last N commits (you'll be asked for the number).
    *   `3`: For a specific commit (you'll be asked for the commit hash).
5.  **Interactive Editor Instructions**: Read the on-screen instructions carefully before pressing Enter to proceed. These instructions explain how to modify the rebase plan in your default text editor (e.g., Nano, Vim, VS Code).
    *   Change `pick` to `reword` (or `r`) for any commit you wish to modify its message.
    *   Change `pick` to `edit` (or `e`) if you want to pause the rebase at a specific commit to make other changes or resolve conflicts.
6.  **Rewrite Commit Messages**: For each commit marked `reword`, your editor will open. Change the commit message as desired, adhering to Conventional Commits standards (e.g., `feat(scope): descriptive message`). Save and close the editor for each message.
7.  **Handle Pauses (if any)**: If the rebase pauses (e.g., due to an `edit` command or conflicts), the script will prompt you to:
    *   `c`: Continue the rebase (after resolving any conflicts manually).
    *   `a`: Abort the rebase.
    *   `q`: Exit the script, leaving the rebase in a paused state.
8.  **Force Push (if needed)**: After the rebase completes, if you have pushed these commits previously, you will likely need to force push your changes to the remote repository:
    ```bash
    git push --force-with-lease
    ```
    Always check your Git history first with `git log --oneline` before force pushing.

## Important Notes

*   **Caution with History Rewriting**: Rewriting Git history can have significant consequences, especially if you are working on a shared branch. Always ensure you understand the implications before proceeding.
*   **Backup**: Consider backing up your branch or repository before performing extensive history rewriting.
*   **Conventional Commits**: It is highly recommended to follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for clear and consistent commit messages.
