// release CI
group "release_ci" {
  targets = ["alpine", "hwaccel"]
  output = ["type=registry"]
}
// develop CI
group "develop_ci" {
  targets = ["alpine-develop", "hwaccel-develop"]
  output = ["type=registry"]
}

// targets
group "default" {
  targets = ["alpine", "hwaccel"]
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

// common arguments
target "_common" {
  context = "."
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v6", "linux/arm/v7"]
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

target "_develop" {
  args = {
    STASH_TAG = "development"
  }
}

// targets
target "alpine" {
  inherits = ["_common"]
  dockerfile = "dockerfile/alpine.Dockerfile"
  tags = tag("alpine")
  cache-to = cache_tag("alpine")
  cache-from = cache_tag("alpine")
}

target "hwaccel" {
  inherits = ["_common"]
  dockerfile = "dockerfile/hwaccel.Dockerfile"
  tags = tag("hwaccel")
  cache-to = cache_tag("hwaccel")
  cache-from = cache_tag("hwaccel")
}

// develop
target "alpine-develop" {
  inherits = ["alpine", "_develop"]
  tags = tag("alpine-develop")
  cache-to = cache_tag("alpine-develop")
  cache-from = cache_tag("alpine-develop")
}

target "hwaccel-develop" {
  inherits = ["hwaccel", "_develop"]
  tags = tag("hwaccel-develop")
  cache-to = cache_tag("hwaccel-develop")
  cache-from = cache_tag("hwaccel-develop")
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
  cache-to = cache_tag("alpine")
  cache-from = cache_tag("alpine")
}

function "cache_tag" {
  params = [variant]
  result = CI ? [{
    type = "registry",
    ref = "ghcr.io/${OWNER_NAME}/${CACHE_IMAGE_NAME}:cache-${variant}",
    mode = "max"
  }] : [{
    type = "registry",
    ref = "stash-s6:cache-local",
    mode = "max"
  }]
}

// functions
// add hwaccel-alpine tag for transition period
function "tag" {
  params = [variant]
  result = concat(
    [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}",
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${SHORT_BUILD_DATE}",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:${variant}-${SHORT_BUILD_DATE}"
    ],
    variant == "alpine" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:latest",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:latest"
    ] : variant == "alpine-develop" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:develop",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:develop"
    ] : variant == "hwaccel" ? [
      "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine",
      "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine"
    ] : []
  )
}