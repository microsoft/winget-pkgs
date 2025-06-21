# Moderation Overview

The Windows Package Manager community repository is the location for manifests published in the default Windows Package Manager source. Automated pipelines validate and publish these manifests. The quality of the metadata has a direct impact on customer experience. Human review has proven to be an invaluable tool for ensuring we can provide the best experiences.

## Moderators

In addition to Microsoft employees, several community members have been identified through their high-quality submissions, willingness to help others, and adherence to our [code of conduct](../CODE_OF_CONDUCT.md).

When we initially implemented moderation, we observed several objective criteria. These included the number of Pull Requests (PR)s made, the length of time they had been active in the project, and their interaction with others who submitted PRs.

Our intent was not to introduce a numbers game for others to achieve and automatically become a moderator. Our goal from now on is to ensure the community is sufficiently supported by individuals who have the technical knowledge and a proven track record of success. Becoming a moderator is like becoming a [Microsoft Most Valuable Professional](https://mvp.microsoft.com/en-us/Pages/what-it-takes-to-be-an-mvp). There isn't a set formula. We're looking at what individual contributors are doing, and how they are doing it. If the need arises to add additional moderators, nominations may come from one of the core team members or an existing moderator. We will publicly disclose the nomination in a discussion. If the nominee agrees to the requirements in this document, they may be awarded the status of moderator.

| Windows Package Manager Administrators |
| ------------------------------------- |
| **[@AmelBawa-msft](https://github.com/AmelBawa-msft)** |
| **[@denelon](https://github.com/denelon)** |
| **[@dkbennett](https://github.com/dkbennett)** |
| **[@erinpwoo](https://github.com/erinpwoo)** |
| **[@florelis](https://github.com/florelis)** |
| **[@hackean-msft](https://github.com/hackean-msft)** |
| **[@JohnMcPMS](https://github.com/JohnMcPMS)** |
| **[@KevinLaMS](https://github.com/KevinLaMS)** |
| **[@Madhusudhan-MSFT](https://github.com/Madhusudhan-MSFT)** |
| **[@msftrubengu](https://github.com/msftrubengu)** |
| **[@ranm-msft](https://github.com/ranm-msft)** |
| **[@RDMacLachlan](https://github.com/RDMacLachlan)** |
| **[@stephengillie](https://github.com/stephengillie)** |
| **[@yao-msft](https://github.com/yao-msft)** |

| Community Moderators |
| -------------------- |
| **[@ImJoakim](https://github.com/ImJoakim)** |
| **[@ItzLevvie](https://github.com/ItzLevvie)** |
| **[@jedieaston](https://github.com/jedieeaston)** |
| **[@KaranKad](https://github.com/KaranKaD)** |
| **[@mdanish-kh](https://github.com/mdanish-kh)** |
| **[@OfficialEsco](https://github.com/OfficialEsco)** |
| **[@quhxl](https://github.com/quhxl)** |
| **[@russellbanks](https://github.com/russellbanks)** |
| **[@Trenly](https://github.com/Trenly)** |

## Expectations

Moderators are expected to continue behaving in a manner consistent with what led to their nomination. In addition, they are given the ability to approve PRs for manifests. This should not be seen as the goal, however. The goal is to help ensure high-quality manifests and to help the community with package submission. They may request to discontinue this responsibility at any time and for any reason, and it will be honored.

### Reviewing Pull Requests

Moderators should review PRs to ensure the metadata is accurate and that the Windows Package Manager will behave predictably with the given manifest. This includes checking the metadata and testing the installation of packages. Ideally, common issues will be documented and referred to for the sake of consistency. This might also include tips and tooling to help with the process. Some users are new to GitHub and may need a bit more support. We've all been new to Git at one point.

### Providing Feedback

Moderators are often on the front line when new issues are identified. They should collaborate with each other, the community, and the product team. This will help ensure the Windows Package Manager continues to improve. Sometimes this could be by creating an Issue or a Discussion. Other times this may just be discussion in a PR. Moderators are ambassadors for the Windows Package Manager. Their tone sets the example others will follow.

## Moderator Tools and Powers

Moderators are given several extra permissions in this repository. This details out some of the actions they can perform.

### Approving Pull Requests

> Trigger: Approve a pull request

Moderators are able to approve most pull requests for automatic merge. When a moderator approves a pull request, the `Moderator-Approved` label will automatically be added. If the automatic validation finds no issues with the pull request, it will be automatically merged.

### Re-Running Pull Request Validation

> Trigger: Comment `@wingetbot run` on a pull request

Occasionally the automatic validation runs into an issue which is transient, or may be solved by re-running the validation. This will remove most error labels and will cause the validation service to start a brand new validation instance.

### Removing Pull Request Feedback

> Trigger: Comment `[Policy] reset feedback` on a pull request

The bots which help keep the repository clean sometimes make mistakes or or sometimes a moderator misclicks and accidentally requests changes. This can add the `Needs-Author-Feedback` or `Needs-Attention` labels to pull requests that don't need them. Moderators can remove these labels without re-running the pipelines to allow for the PR to be re-reviewed and merged.

### Removing Labels

> Trigger: Comment `[Policy] Reset Labels` on a pull request or issue

Sometimes a label is misapplied or needs to be removed to keep things clean. This trigger will remove all labels that moderators have access to as well as some non-blocking pipeline labels such as `Possible-Duplicate`. After using this trigger, the applicable labels should be re-added using the triggers below.

### Closing or Re-opening Pull Requests and Issues

> Trigger: Comment `Close with reason: <reason>;` on a pull request or issue

> Trigger: Comment `Reopen with reason: <reason>;` on a pull request or issue

In order to help keep the issues queues clean, moderators are able to close/re-open pull requests and issues. It is important to exercise discretion when closing/re-opening, ensuring that it is done with good reason.
> [!IMPORTANT]
> The ending semicolon is required. Using a URL in the reason is not supported

### Marking Issues as Duplicate

> Trigger: Comment `Duplicate of #<number>`

When duplicate issues are raised, moderators are able to use this special variation of the close command to mark them as duplicate. This adds the `Resolution-Duplicate` label and provides additional information to the issue's author, as opposed to simply closing the issue.
> Note: This does not work for cross-repository duplicates

### Tagging of Issues and Pull Requests

> Trigger: Comment `[Policy] <label-name>`

Moderators are often the first to see and triage new issues, and so they have the ability to apply certain labels to pull requests and issues. Below is a list of labels that moderators can apply:

* `Area-Bots`
* `Area-Client`
* `Area-External`
* `Area-Matching`
* `Area-Publish-Pipeline`
* `Area-Rebuild-Pipeline`
* `Area-Scope`
* `Area-Validation-Pipeline`
* `Blocking-Issue`
* `Dependencies`
* `DriverInstall`
* `DSC`
* `Error-Hash-Mismatch`
* `Error-Installer-Availability`
* `Hardware`
* `Help-Wanted`
* `Highest-Version-Removal`
* `Icon`
* `In-PR`
* `Installer-Error`
* `Installer-Issue`
* `Interactive-Only-Download`
* `Interactive-Only-Installer`
* `Issue-Bug`
* `Issue-Docs`
* `Issue-Feature`
* `Last-Version-Removal`
* `License-Blocks-Install`
* `Manifest-Content-Incomplete`
* `Manifest-Singleton-Deprecated`
* `Moderator-Approved`
* `Needs-Attention`
* `Needs-Author-Feedback`
* `Needs-CLA`
* `Needs-Manual-Merge`
* `Needs-Review`
* `Network-Blocker`
* `Package-Request`
* `Package-Update`
* `Portable-Archive`
* `Portable-JAR`
* `PSA`
* `Scripted-Application`
* `Testing`
* `Upgrade-Issue`
* `Validation-Skip-Automations`
* `Version-Parameter-Mismatch`
* `Windows-Features`
* `Zip-Binary`

> [!NOTE]
>
> * Applying the following labels will automatically add `Blocking-Issue`
>   * `Hardware`
>   * `Interactive-Only-Installer`
>   * `License-Blocks-Install`
>   * `Portable-Archive`
>   * `Windows-Features`
>   * `Zip-Binary`
> * Adding `Needs-Attention` to a PR will automatically assign the repository maintainers
> * `[Policy] Unblocked` will remove `Blocking-Issue` label.
