SHELL := /bin/bash
.DEFAULT_GOAL := help
ROOT_PATH := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
BIN_PATH := $(ROOT_PATH)/.local/bin

VERSION := $(shell git describe --tags `git rev-list --tags --max-count=1 2> /dev/null` 2> /dev/null || echo v0.0.0)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
GIT_DIRTY := $(shell test -n "`git status --porcelain`" && echo "+CHANGES")
RELEASE_VERSION ?= $(VERSION)-$(GIT_COMMIT)
BUILD_DATE := $(shell date '+%Y-%m-%d-%H:%M:%S')
ENVIRONMENT ?= develop

# Import our project var file (if exists)
PROJECT_VARS ?= ${ROOT_PATH}/config/project.env
ifneq (,$(wildcard $(PROJECT_VARS)))
include ${PROJECT_VARS}
export $(shell sed 's/=.*//' ${PROJECT_VARS})
endif

# Import target deployment env vars
ENVIRONMENT_VARS ?= ${ROOT_PATH}/config/deploy.$(ENVIRONMENT).env
ifneq (,$(wildcard $(ENVIRONMENT_VARS)))
include ${ENVIRONMENT_VARS}
export $(shell sed 's/=.*//' ${ENVIRONMENT_VARS})
endif

# Import sane defaults for vars
-include $(ROOT_PATH)/config/makefile.defaults

# Import provider specific tasks
-include $(ROOT_PATH)/scripts/makefile.gitprovider.$(GIT_PROVIDER)
-include $(ROOT_PATH)/scripts/makefile.k8sprovider.$(KUBE_PROVIDER)
-include $(ROOT_PATH)/scripts/makefile.dockerprovider.$(DOCKER_PROVIDER)
-include $(ROOT_PATH)/scripts/makefile.pipelineprovider.$(PIPELINE_PROVIDER)

# Import some standard task sets
-include $(ROOT_PATH)/scripts/makefile.common
-include $(ROOT_PATH)/scripts/makefile.deployment
-include $(ROOT_PATH)/scripts/makefile.kubernetes
-include $(ROOT_PATH)/scripts/makefile.shared
-include $(ROOT_PATH)/scripts/makefile.docker

# Import the language tasks
-include $(ROOT_PATH)/scripts/makefile.golang


.print-%: # Print a make variable for github actions
	@echo '$*::$($*)'

.printshort-%: # Print a variable value
	@echo '$($*)'

.PHONY: deps
deps: .cicd/deps .kube/deps .pipeline/deps .deployment/deps .go/deps ## Install general dependencies

.PHONY: show/build/info
show/build/info: ## Show various build settings
	@echo "PROJECT_VENDOR: $(PROJECT_VENDOR)"
	@echo "PROJECT_APP: $(PROJECT_APP)"
	@echo "DOCKER_IMAGE: $(DOCKER_IMAGE)"
	@echo "REPO: $(GIT_SITE)"
	@echo "GO_VERSION_REQUIRED: $(GO_VERSION)"
	@echo "GO_VERSION_FOUND: $(shell go version)"
	@echo "GOPATH: $(GOPATH)"
	@echo "VERSION: $(VERSION)"
	@echo "GIT_COMMIT: $(GIT_COMMIT)"
	@echo "GIT_DIRTY: $(GIT_DIRTY)"
	@echo "BUILD_DATE: $(BUILD_DATE)"
	@echo "RELEASE_VERSION: $(RELEASE_VERSION)"
	@echo "LDFLAGS: $(LDFLAGS)"

# .PHONY: release
# release:
# 	git add -all .
# 	git commit -m "release: commit before release"
# 	git tag -a v$(RELEASE_VERSION) -m "auto-release"
# 	git push origin master --tags
