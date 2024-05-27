### Checklist
- [ ] Adding a changelog: In the `changelog.d` directory, create a file named `<code>.<type>`.

  `<code>` can be anything, but we recommend using a more or less unique identifier to avoid collisions, such as the branch name.

  `<type>` can be `add`, `change`, `remove`, `fix`, `security` or `skip`. `skip` is only used if there is no user-visible change in the MR (for example, only editing comments in the code). Otherwise, choose a type that corresponds to your change.

  In the file, write the changelog entry. For example, if an MR adds group functionality, we can create a file named `group.add` and write `Add group functionality` in it.

  If one changelog entry is not enough, you may add more. But that might mean you can split it into two MRs. Only use more than one changelog entry if you really need to (for example, when one change in the code fix two different bugs, or when refactoring).
