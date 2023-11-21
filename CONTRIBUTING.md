# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional
documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary
information to effectively respond to your bug report or contribution.


## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

* A reproducible test case or series of steps
* The version of our code being used
* Any modifications you've made relevant to the bug
* Anything unusual about your environment or deployment


## Contributing via Pull Requests
Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the *main* branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure local tests pass.
4. Commit to your fork using clear commit messages.
5. Send us a pull request, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).


## Finding contributions to work on
Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels (enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.


## Code of Conduct
This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.


## Security issue notifications
If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.


## Licensing

See the [LICENSE](LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.

# Contributing to the Smart-Restart

All contributions to the Smart-Restart package are welcome and should be made via GitHub [pull
requests](ADD-LINK) and discussed using GitHub [issues](ADD-LINK).

## Before you start

If you would like to make a significant change, it's a good idea to first open
an issue to discuss it.

## Making the request

Development takes place against the `dev` branch of this repository and pull
requests should be opened against that branch.

## Testing

Smart-Restart comes with a preset of tests checking the happy and fail path for
all three main components:

1) Restarting services & denylisting
2) Reboothint maker file generation
3) Correct execution order for the pre & post restart hooks

The subfolder `test` contains scripts prefixed with "test-" which are executed with the `make test` target.

Each new test script must source the `setup_test` harness. It is also advicable to provide a TEST_NAME
```
TEST_NAME="MY NEW TEST"
. "$(pwd)"/setup_test
```

Then, the individual functions from `smart-restart.sh` can be called.

Smart-Restarting provides mocks for `systemctl` and `needs-restarting` where their functionality can be
controlled using variables. For example

```
NEED_RESTART_2=1 assemble_service_list
```

will instruct `needs-restarting` called in the `smart-restart.sh:assemble_service_list()` to return 2 services
requiring a restart. In analogy `NEED_RESTART_0=1` will report 0 services.

`systemctl` mock can be instructed to expect a amount of services using `SYS_EXPECT_{0,1,2}=1`.

Additionally, the mocks themselves can be overriden.

```
SYSCTL_COMMAND=/bin/false restart_services || retval="$?"
```

In this case, the test will fail, if restart_services tries to execute the mocked `systemctl`.
