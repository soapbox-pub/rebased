### Release checklist
* [ ] Bump version in `mix.exs`
* [ ] Compile a changelog
* [ ] Create an MR with an announcement to pleroma.social
#### post-merge
* [ ] Tag the release on the merge commit
* [ ] Make the tag into a Gitlab Release™
* [ ] Merge `stable` into `develop` (in case the fixes are already in develop, use `git merge -s ours --no-commit` and manually merge the changelogs)
