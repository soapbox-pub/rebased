# Setting up a Gitlab-runner

When you push changes, a pipeline will start some automated jobs. These are done with so called [runners](https://docs.gitlab.com/runner/), services that run somewhere on a server and run these automated jobs. These jobs typically run tests and should pass. If not, you probably need to fix something.

Generally, Pleroma provides a runner, so you don't need to set up your own. However, if for whatever reason you want to set up your own, here's some high level instructions.

1. We use docker to run the jobs, so you should install that. For Debian, you need to allow non-free packages in the [source list](https://wiki.debian.org/SourcesList). Then you can install docker with `apt install docker-compose`.
2. You can [install](https://docs.gitlab.com/runner/install/index.html) and [configure](https://docs.gitlab.com/runner/register/index.html) a Gitlab-runner. It's probably easiest to install from the packages, but there are other options as well.
3. When registering the runner, you'll need some values. You can find them in the project under your own name. Choose "Settings", "CI/CD", and then expand "Runners". For executor you can choose "docker". For default image, you can use the image used in <https://git.pleroma.social/pleroma/pleroma/-/blob/develop/.gitlab-ci.yml#L1> (although it shouldn't matter much).
