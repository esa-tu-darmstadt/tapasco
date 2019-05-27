# TaPaSCo Contributor's Guide #

This guide assembles important information for people interested in contributing
to TaPaSCo.

## Intro ##

The code base of TaPaSCo consists of three main parts:

* The `tapasco` tool for interfacing with HLS, composing designs and running
design-space exploration. This part is written entirely in ***Scala***.

* The definitions of platforms, architectures, features and plugins. These are
mostly written in ***TCL***, a language understood by most EDA/CAD tools.

* The TaPaSCo API and Linux kernel driver (*TaPaSCo loadable kernel module*,
   tlkm) for interfacing with accelerators from software. This part is written
   in ***C/C++***.

We welcome contributions to all three parts. If you want to contribute to
TaPaSCo, but do not know where to start, you can either have a look at issues
on Github [labeled with "good first issue"](https://github.com/esa-tu-darmstadt/tapasco/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22+no%3Aassignee)
or [contact us](mailto:tapasco@esa.tu-darmstadt.de).

## Coding Style ##

The (at least) four different languages currently used in the TaPaSCo code base
of course require different coding styles and practices. Nevertheless, there is
a number of general guidelines you should follow:

* **Use idiomatic code style:** For each of the languages, there is a set of
commonly accepted best practices, idioms and styling guidelines. Follow these
practices.

* **Use meaningful names for functions, variables, classes, etc.:** This should
go without saying, however, we want to remind you to use meaningful names
for the entities in your code.

* **Document your code:** This should also be a given. Include comments in your
code, in particular for complicated statements or parts difficult to understand.

* **Follow the given identation scheme:** You should use the same scheme for
identation as the existing code base, even if that does not match your personal
preference. Please also make sure that your editor/IDE is not breaking things
in the background.

* **Test your code:** Make sure everything still works as expected, after you
have introduced your change to the code. We do have CI in place, however we
cannot test every usage scenario with that. Please try to make sure to test the
functionality affected by your changes. For Scala, you can additionally provide
tests, which will be run with the `sbt test`-command by CI.

* **Add copyright header:** In case you create a new file, make sure to include
the TaPaSCo copyright header.

## Contribution Process ##

TaPaSCo uses the [git-flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model for development. In short,
this means that the `develop`-branch is the central branch for development.
Features are developed on so-called feature branches, which are merged into
`develop` when the feature is complete. For releases, a release-branch is
forked from the develop branch and eventually merged into `master` to mark a
release. Please make yourself familiar with the git-flow model before starting
to develop.

The overall process for contributing to TaPaSCo looks as follows:

1. Create a fork of TaPaSCo under your personal account or your organization.
Simply use Github's fork-button for that.

2. Create a feature-branch (or hotfix, whatever applies) from develop. We use
the default naming convention of the [git flow-extension](https://de.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow), make sure to follow the same
convention (feature branches are prefixed with "feature/"). Use a meaningful
name for your feature branch.

3. Commit your changes to the feature branch. During development, make sure to
follow the coding style guidelines listed above. Also avoid unrelated changes,
i.e. changes to parts of the code that have nothing to do with your feature, as
these make it hard to review a contribution.

4. After you have completed your feature, create a new pull request in the
main TaPaSCo repository on Github. Make sure to setup **develop** as the target
branch of your pull request. In the pull request, provide a short description
of your feature that we can also use for release notes.

5. The pull request feature of Github will show you whether your branch can be
merged automatically (no conflicts) or needs manual merging. In the first case,
we will use the automatic **rebase and merge**-feature to merge your feature
after review. In the latter case, please manually integrate the changes that have
happened on the `develop`-branch while you were developing your feature using
`git merge`. If you need changes from new commits on `develop` during the
development of your feature (e.g. hotfixes), please also use `git merge` to
integrate them into your branch.

6. Request a review by one of the TaPaSCo maintainers (@jahofmann, @cahz, @sommerlukas).
We will review your changes, giving you feedback on your code.

7. When the review process is done, we will accept the pull request, merging
your changes into `develop`. From this moment on, your feature will be part
of TaPaSCo and you will have the honor of being a TaPaSCo contributor ;-)
When the next release occurs on `master`, your feature will automatically be part
of it.

If this process seems too complicated to you or you only have a small one-off
change to make, you can also [contact us](mailto:tapasco@esa.tu-darmstadt.de)
with a patch.
