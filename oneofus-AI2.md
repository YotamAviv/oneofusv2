These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation


read AI.md


read AI.md
DO NOT EDIT FILES!
DO NOT RUN COMMANDS!
ANSWER MY QUESTIONS!


read AI.md
read the testing docs
run all tests, unti and integration tests included.


read AI.md
run git status
run git diff on every change between this branch and the main branch
read those changes
Let me know if you notice anything that might be problematic.
If not, suggest a commit message based only on the GIT diffs, not based on your memory
Copy/paste from our conversation never works for me for this, and so
append the commit message to the end of this file:
Dialog refinements and UX improvements

WelcomeScreen:
- Add "You have no keys on this device" heading on first launch
- Use 'WELCOME' header instead of 'Welcome'
- Uppercase 'Welcome' text

EditStatementDialog:
- Add explanatory text for all actions (Trust, Block, Delegate, Replace)
- Refactor description logic to use a static map with strict typing
- Inline description text directly into the build method

ReplaceFlow:
- Remove blocking check that verified if a scanned identity had network history
- This allows claiming/replacing keys that were passive (received vouches but made no statements)
- Fix bug in history fetch where sorting was attempted on an immutable list

StatementCard:
- Use Labeler to resolve labels for keys including "Unknown" ones
- This ensures keys in "Manage Identity History" show correct labels like "Me (2)"

Other:
- Update copy in QrScanner
- Update copy in AppShell for scanning instructions

