# OneOfUs — Claude Instructions

Run all tests: `bin/run_all_tests.sh`
Never commit without being explicitly asked.

Shared packages in `packages/` are meant to be identical across all three repos (hablotengo, nerdster, oneofus). See `packages/README.md`.

## Answering

Answer the question asked, and stop. A yes/no question gets yes or no first.

- No preamble, no restating my question back, no summary of what you just did.
- Don't narrate plans or list what's still outstanding unless I ask.
- Don't invent what I think or expect and then correct it.
- Comments in code earn their space by recording a trap someone hit. Anything
  that narrates the line below it is noise.
