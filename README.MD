# Hello-World-Pipeline

An example pipeline for Hello World for Kubernetes using a Gitflow(ish) model to deploy to multiple environments.

## Requirements

The pipeline for this project is all able to be run directly within Github Workflows. Locally, the project was created on Linux with Docker and Go. All CI tasks can be run without docker using the included Makefile. This includes a task to pull in all external stand-alone binaries that are used for constructing a kind based kubernetes cluster instance and the tools for deploying this project into a running cluster. 

```bash
## Show all available make tasks
make

## Download and install all stand-alone binaries used for this project
make deps
```

> **NOTE** All external binaries are purposefully stand-alone and pulled into an ingored `.local/bin` directory with a `make deps` command. This step is required for helm deployments, chart updates, and local pipeline testing. It also pulls in the correct version of kubectl that aligns with the version of Kubernetes being targeted for the deployment.

Two additional tools can be used for quality of life enhancements in the shell and would require additional configuration depending on your shell. [asdf-vm](https://asdf-vm.com/#/) and [direnv](https://direnv.net/). If asdf and direnv are hooked into your shell then the included .envrc will automatically setup the required version of Go and set appropriate paths for the development environment as well.

## Github

The github repo was manually updated in the following ways;

- Default branch is set to `develop` to align with gitflow.
- Added `DOCKER_USERNAME` and `DOCKER_PASSWORD` for DockerHub integration.

## The Pipeline

The pipeline process for this example has taken some shortcuts for the following reasons;

1. We are not using any centralized helm repository. As such we lint the helm chart and simply use it locally to deploy to kubernetes instead of creating a versioned chart artifact.
2. There is no centralized configuration management (like Consul) in this example. To work around this, I use local environment variable files along with gomplate templating.
3. We are not working with any sort of enterprise docker registry or git repo either, this somewhat limits our ability to optimize things like the build images without needless complications. In an enterprise environment the build images would need to be localized and deployed via their own pipeline/repo and used in the pipelines for this build process.
4. The base images for the multi-stage build are sourced from external locations and would also need to be internal images in an enterprise environment.
5. There are no target kubernetes clusters to deploy into as this is an example pipeline only. As such, we include additional pipeline tasks to stand up a kind (Kubernetes in docker) cluster and deploy to it right afterwards.

The pipeline is being performed via Github Actions workflows. The table for how/when these workflows are triggered can be found further down in this document in the [Gitflow section](#gitflow-ish).

If you wish to run things locally, every step of the pipeline can be done using the local Makefile tasks instead.

```bash
## lint, test, build, then run the local binary
make lint test build run

## lint, test first. Then build, tag, then run the local docker image
make lint test docker/image docker/tag docker/run

## push the image to dockerhub
make docker/login docker/push
```

> **NOTE** There are additional tasks for pushing the image and more.

## The App

The app is a simple Go app that runs the [gin framework](https://gin-gonic.com/) to serve up a template file in web/template on port 8000. 

## Build

The CI performs the following actions:

- Code Coverage
- Unit Tests
- Helm chart override rendering
- Build/Tag/Push Docker Image

## Deploy

If this is the develop branch then the CI will be immediately followed by the CD for a release. This includes:

- Create a local kind (kubernetes) cluster
- Apply the rendered chart override for dev to the new cluster

The deployment will also be triggered for a new tag release. This will 

- Create a binary github releases artifact with GoReleaser
- Create a local kind (kubernetes) cluster
- Apply the rendered chart override for prod to the new cluster


## Branch Model - Gitflow

Gitflow wasn't necessarily designed for multiple release environments. So adaptations need to be made to accommodate the requirement for using it as the Git branching strategy in this example. 

A project release manager should be assigned to ensure that the schemantic versioning of the code base is performed when new release-* branches are started and a regular cadence for releases should be established if gitflow will be used. Additionally, the ground rules for the model should be laid out so I'll do so in the following sections.

In our case we will use the following environments and triggers for releases into them.

| Release Environment | Action | Branch | Trigger |
|---|---|---|---|
| N/A | Build | develop, release/, hotfix/, feature/ | Any update to branches with this name |
| dev | Build/Deploy | develop | Any updates to the develop branch |
| prod | Deploy | master | Any new tags to the master branch |

Additionally, there are manual tasks required in a typical gitflow model that are done automatically in a separate Github Workflow. This workflow will do the following;

- Automatically creates and merges pull requests from master to develop branches
- Automatically creates and merges pull requests from release to master.

Because of this we will use additional pipeline logic to prevent build/deploy processes from running when a merge to develop from master occurs.

## Branches

The following branch naming strategy should be followed for this project as it (mostly*) adheres to the gitflow model.

| Name | Description | Time to live | Example |
|--|--|--|--|
| master | Rreflects a production-ready state. After code has been validated in a release branch and pushed to production, the code is merged to the master branch. However, this doesn't fully align with multiple releases installed concurrently on different environments.| Permanent | master |
| develop | Reflects a production-ready state. After code has been validated in a release branch and pushed to production, the code is merged to the master branch. However, this doesn't fully align with multiple releases installed concurrently on different environments. | Permanent | develop |
| feature/{sprint}-{short description} | feature branches are used to develop new features for the upcoming or a distant future release. The essence of a task branch is that it exists if the story/task (feature) is in development but will **eventually be merged back into develop** (to add the new feature to the upcoming release) or **discarded** (in case the business goals have been changed). | Short-term | feature/12301-cdnimplem |
| hotfix/{sprint}-{short description} | **Hotfix** branches are like bugfix branches, but created from **release** branches and intended to fix issues in them once the release that is currently deployed in PROD. | Short-term | hotfix/3-uifix |
| bugfix/{sprint}-{short description} | Bugfix branches are like feature branches but created not for a development of a new feature but to fix an issue in develop or release/* branch. | Short-term | bugfix/3-myfix |
| release/v{MajorVer}.{MinorVer}.{PatchVer} | Release branches are created when the develop branch is at a stable point and release specific changes need to be made, such as bumping version numbers, etc. At that point, develop should be branched and the changes made before ultimately merging it into master and tagging the release. There should only be one active release branch at a time. | Short-term | release/v1.1.0 |

> **NOTE 1:** This project uses the free version of github which does not allow for branch protection rules that would need to be implemented in an enterprise environment!

> **NOTE 2*:** We use branch naming slightly different than gitflow dictates by using a `/` instead of a `-`. This allows for some branch rollup visualization options in certain platforms and can be a way to keep repos with a ton of branches cleaner at the branch root.

## Kubernetes Deployment

The current cluster creation is based on kind (kubernetes in docker) and is run inline via the pipeline for lack of an environment to target otherwise. If you will be building and running this deployment locally then the version of the kubernetes cluster can be defined in the project.env and must align with a released tag for the kind project ([found here](https://hub.docker.com/r/kindest/node/tags)). Otherwise, the most recent version will be deployed within the pipeline code (it would be a nominal task to include this versioning in a production pipeline deployment pipeline)

Most people seem to know of or use Helm so this is what we will be utilized for deployment of this test application to our cluster. Helm 3 will be implemented in this regard and we will be rendering our helm chart override values file using gomplate. Gomplate can use various backends like consul or others so it makes for a fairly pluggable system down the line if centralized config managment were to be implemented instead of simple env var files.

> **NOTE:** Deployment variables for targeted environments are stored within this repo in `./config/deploy.<target>.env`. Currently only develop and prod are defined. The pipeline code will determine which to use based on the current branch being run. Only master branch will be considered for targeting the prod environment. Develop and feature/* branches will target the develop environment.

To run kind locally for deployment testing you can use some included tasks.

```bash
# To start a local cluster and set your context to it.
make start/cluster kube/context

# To destroy a local cluster
make stop/cluster

# deploy helm chart to local cluster (use output to setup proxy to cluster to validate the hello world website is running)
make helm/deploy

# Test the deployed chart service automatically with a test pod
make helm/test
```

> **WARNING:** The chart deployment to a local kind cluster assumes a versioned image has already been deployed to dockerhub via the github workflow. If developing code this is a sub-optimal experience so alternatives for in-cluster development should be further explored/considered. There are ways to force the kind cluster to use a locally depoyed registry [found here](https://kind.sigs.k8s.io/docs/user/local-registry/)

## Versioning

[Semantic Versioning](https://semver.org/) are being used per best practice. As it aligns with Go module release versioning we will use the git tag as the version for deployment. The pipelines for this project produces the following artifacts with versions.

| Artfact | Artifact Location | Created With | Branch(s) | Version | Example |
|---|---|---|---|---|---|
| Binary Release | Github Releases | GoReleaser | master | Git Tag | v0.0.1 |
| Docker Image | DockerHub | Docker | develop | Git Tag+Commit Hash(short) | v0.0.0-f038f38 |
| Docker Image | DockerHub | Docker | master | Git Tag | v0.2.0 |
| Helm Chart Override | Pipeline Artifact | Script | develop | Git Tag+Commit Hash(short) |
| Helm Chart Override | Pipeline Artifact | Script | master | Git Tag |

> **NOTE:** The helm chart is currently not versioned. Instead the image tag is passed through to the chart for deployment. This is a common practice but ideally the chart itself would be packaged up as a whole with an updated version in the Chart.yaml manifest instead.

## Dev Workflow

Using the gitflow git extension (in some areas) we will demonstrate a full workflow from feature to release.

### Add a Feature

```bash
## Start a feature from develop (the default branch)
git flow feature start initial-release
git add --all . && git commit -m 'feature: initial release'
git push origin feature/initial-release
```
This will lead to a workflow that runs the CI process only. No docker image will be published.

### Complete a Feature

Initialize a pull request into develop for the feature branch. In the github console create a pull request for the feature manually or used the included `gh` CLI tool to do the same:

```bash
./.local/bin/gh pr create -B develop -f
```

In the github console, approve and merge the request and delete the feature/ branch as gitflow dictates. This will kick off the CI process, create a new tagged image, and run through the (fake) deployment process into a kubernetes cluster then test the deployment with the built in helm chart tests.

### Start a Release

To start a release go back to develop branch and begin the release process.

```bash
## Pull merged features or other changes
git checkout develop
git branch --set-upstream-to=origin/develop develop
git pull
git flow release start v0.1.0

## Make some small changes, ideally you would bump any version files that may be required. We use tags for versions so we will not do this.
git add --all . && git commit -m 'release: v0.1.0'
git push origin release/v0.1.0
git flow release finish 'v0.1.0'
```

When this is completed the release/v0.1.0 branch will have been merged into master and a new tag been generated. This will kick off the production deployment pipeline for this release.

## Extras

Here are quite a few additional tasks in the Makefiles that are broken out by category in the scripts directory. Running `make` at the root directory will show all non-hidden tasks (those not prefixed by a `.`). Many of these are one off tasks I needed to do at some point and just dropped into a Makefile for future use. These may or may not be valuable to the right devops engineer as items to cut apart for their own custom pipelines so I just left them in.

The only task that would require elevated rights is the hidden `.dep/gitflow` task. This will install the gitflow git extension that can be used to make the gitflow experience quite a bit easier for a developer. 

A few more interesting things that can be done with this scaffolding are listed below.

```bash
# Check if the current git commit hash has a pushed image (perhaps use to skip an entire build)
make docker/list | grep -w $(make .printshort-RELEASE_VERSION)
```

# Links

[Standard Go Project Layout](https://github.com/golang-standards/project-layout)

[Gin Web Framework](https://gin-gonic.com/)

[Gitflow](https://nvie.com/posts/a-successful-git-branching-model/)

[Gitflow Git Extension](https://github.com/nvie/gitflow)

[Semantic Versioning](https://semver.org/)

[GoReleaser Github Actions](https://goreleaser.com/actions/)

[asdf-vm](https://asdf-vm.com/#/)

[direnv](https://direnv.net/)

# About Me

[Zachary Loeber's Blog](https://zacharyloeber.com)

[Zachary Loeber's Linkedin Profile](https://www.linkedin.com/in/zloeber/)

# Status Badges

develop branch: ![Build](https://github.com/zloeber/hello-world-pipeline/workflows/Build/badge.svg?branch=develop&event=status)

master branch: ![Build](https://github.com/zloeber/hello-world-pipeline/workflows/Build/badge.svg?branch=master&event=status)
