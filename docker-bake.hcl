// release CI
group "release_ci_alpine" {
  targets = ["alpine", "hwaccel-alpine"]
  output = ["type=registry"]
}

group "release_ci_debian" {
  targets = ["hwaccel"]
  output = ["type=registry"]
}

// develop CI
group "develop_ci_alpine" {
  targets = ["alpine-develop", "hwaccel-alpine-develop", "hwaccel-develop"]
  output = ["type=registry"]
}

group "develop_ci_debian" {
  targets = ["hwaccel-develop"]
  output = ["type=registry"]
}

// targets
group "default" {
  targets = ["alpine", "hwaccel-alpine", "hwaccel"]
}

// variables
variable "OWNER_NAME" {
  type = string
  default = "feederbox826"
}

variable "IMAGE_NAME" {
  type = string
  default = "stash-s6"
}

variable "CACHE_IMAGE_NAME" {
  type = string
  default = "${IMAGE_NAME}-cache"
}

variable "SHORT_BUILD_DATE" {
  type = string
  default = formatdate("YYYY-MM-DD", BUILD_DATE)
}

variable "BUILD_DATE" {
  type = string
  default = timestamp()
}

variable "GITHASH" {
  type = string
  default = "local-build"
}

variable "CI" {
  type = bool
  default = false
}

// upstream stash build this image packages. CI pins it to a digest so a bake cannot pick
// up an upstream image published mid-build; left empty, the develop targets keep following
// the floating `development` tag for local builds.
variable "UPSTREAM_STASH" {
  type = string
  default = ""
}

variable "UPSTREAM_NAME" {
  type = string
  default = ""
}

variable "UPSTREAM_DIGEST" {
  type = string
  default = ""
}

// stash version read from the pinned upstream image, used for the version tag and label
variable "STASH_VERSION" {
  type = string
  default = ""
}

// common arguments
target "_common" {
  context = "."
  attest = [{
      type = "provenance"
      mode = "max"
  }, {
    type = "sbom"
  }]
  args = {
    BUILD_DATE = BUILD_DATE,
    SHORT_BUILD_DATE = SHORT_BUILD_DATE,
    GITHASH = CI ? GITHASH : "local-build"
  }
}

target "_alpine_multi" {
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v6", "linux/arm/v7"]
}

target "_debian_multi" {
  platforms = ["linux/amd64", "linux/arm64"]
}

target "_develop" {
  args = {
    STASH_TAG = "development"
    # a digest-qualified UPSTREAM_STASH wins in the Dockerfile's `FROM`; the plain tag is
    # only the fallback for local builds
    UPSTREAM_STASH  = UPSTREAM_STASH != "" ? UPSTREAM_STASH : "docker.io/stashapp/stash:development"
    UPSTREAM_NAME   = UPSTREAM_NAME != "" ? UPSTREAM_NAME : "docker.io/stashapp/stash:development"
    UPSTREAM_DIGEST = UPSTREAM_DIGEST
    STASH_VERSION   = STASH_VERSION
  }
}

// targets
target "alpine" {
  inherits = ["_common", "_alpine_multi"]
  dockerfile = "dockerfile/alpine.Dockerfile"
  tags = tag("alpine")
  cache-to = cache_to("alpine")
  cache-from = cache_from("alpine")
}

target "hwaccel-alpine" {
  inherits = ["_common", "_alpine_multi"]
  dockerfile = "dockerfile/hwaccel-alpine.Dockerfile"
  tags = tag("hwaccel-alpine")
  cache-to = cache_to("hwaccel-alpine")
  cache-from = cache_from("hwaccel-alpine")
}

target "hwaccel" {
  inherits = ["_common", "_debian_multi"]
  dockerfile = "dockerfile/hwaccel.Dockerfile"
  tags = tag("hwaccel")
  cache-to = cache_to("hwaccel")
  cache-from = cache_from("hwaccel")
}

// develop
target "alpine-develop" {
  inherits = ["alpine", "_develop"]
  tags = tag("alpine-develop")
  cache-to = cache_to("alpine-develop")
  cache-from = cache_from("alpine-develop")
}

target "hwaccel-alpine-develop" {
  inherits = ["hwaccel-alpine", "_develop"]
  tags = tag("hwaccel-alpine-develop")
  cache-to = cache_to("hwaccel-alpine-develop")
  cache-from = cache_from("hwaccel-alpine-develop")
}

target "hwaccel-develop" {
  inherits = ["hwaccel", "_develop"]
  tags = tag("hwaccel-develop")
  cache-to = cache_to("hwaccel-develop")
  cache-from = cache_from("hwaccel-develop")
}

# local test
target "local-test" {
  context = "."
  dockerfile = "dockerfile/alpine.Dockerfile"
   args = {
    BUILD_DATE = BUILD_DATE,
    SHORT_BUILD_DATE = SHORT_BUILD_DATE,
    GITHASH = "local-build"
  }
  tags = ["stash-s6:local-test"]
  cache-to = cache_to("alpine")
  cache-from = cache_from("alpine")
}

function "cache_from" {
  params = [variant]
  result = [{
    type = "registry",
    ref = "ghcr.io/${OWNER_NAME}/${CACHE_IMAGE_NAME}:cache-${variant}"
  }, {
    type = "registry",
    ref = "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}"
  }]
}

function "cache_to" {
  params = [variant]
  result = CI ? [{
    type = "registry",
    ref = "ghcr.io/${OWNER_NAME}/${CACHE_IMAGE_NAME}:cache-${variant}",
    mode = "max",
    compression = "zstd"
  }] : []
}

// functions
function "tag" {
  params = [variant]
  result = concat(
    [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}",
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${SHORT_BUILD_DATE}",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${SHORT_BUILD_DATE}"
    ],
    STASH_VERSION != "" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${STASH_VERSION}",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${STASH_VERSION}"
    ] : [],
    variant == "alpine" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:latest",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:latest"
    ] : variant == "alpine-develop" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:develop",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:develop"
    ] : []
  )
}