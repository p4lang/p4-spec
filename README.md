# p4-spec

- api: This folder keeps documents related to run-time API auto-generation discussions.
- general: This folder keeps general discussion materials related to the working group activities.
- p4-14: This holds the official P4 14 spec and discussion materials.
- p4-16: This holds the official P4 16 spec and discussion materials.

# Modification Policy

We use the following processes when making changes to the P4 language specification and associated documents. These processes are designed to be lightweight, to encourage active participation by members of the P4.org community, while also ensuring that all proposed changes are properly vetted before they are incorporated into the repository and released to the community.

## Core Processes

* Only members of the P4.org community may propose changes to the P4 language specification, and all contributed changes will be governed by the Apache-style license specified in the P4.org membership agreement.

* We will use [semantic versioning](http://semver.org/) to track changes to the P4 language specification: major version numbers track API-incompatible changes; minor version numbers track backward-compatible changes; and patch versions make backward-compatible bug fixes. Generally speaking, the P4 language design working group co-chairs will typically batch together multiple changes into a single release, as appropriate.

## Detailed Processes

We now identify detailed processes for three classes of changes. The text below refers to [key committers](https://github.com/orgs/p4lang/teams/p4lang-key-committers), a GitHub team that is authorized to modify the specification according to these processes.

1. **Non-Technical Changes:** Changes that do not affect the definition of the language can be incorporated via a simple, lightweight review process: the author creates a pull request against the specification that a key committer must review and approve. The P4 Language Design Working Group does not need to be explicitly notified. Such changes include improvements to the wording of the specification document, the addition of examples or figures, typo fixes, and so on.

2. **Technical Bug Fixes:** Any changes that repair an ambiguity or flaw in the current language specification can also be incorporated via the same lightweight review process: the author creates a GitHub issue as well as a pull request against the specification that a key committer must review and approve. The key committer should use their judgment in deciding if the fix should be incorporated without broader discussion or if it should be escalated to the P4 Language Design Working Group. In any event, the Working Group should be notified by email.

3. **Language Changes** Any change that substantially modifies the definition of the language, or extends it with new features, must be reviewed by the P4 Language Design Working Group, either in an email discussion or a meeting. We imagine that such proposals would go through three stages: (i) a preliminary proposal with text that gives the motivation for the change and examples; (ii) a more detailed proposal with a discussion of relevant issues including the impact on existing programs; (iii) a final proposal accompanied by a design document, a pull request against the specification, and prototype implementation on a branch of `p4c`, and example P4 programs that illustrate the change. After approval, the author would create a GitHub issue as well as a pull request against the specification that a key committer must review and approve.