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
  # caching logic
  cache-to = CI ? [{
      type = "gha"
      mode = "max"
    }] : [{
      type = "inline"
      mode = "max"
    }]
  cache-from = CI ? [{
      type = "gha"
    }] : [{
      type = "inline"
    }]
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
  }
}

// targets
target "alpine" {
  inherits = ["_common", "_alpine_multi"]
  context = "."
  dockerfile = "dockerfile/alpine.Dockerfile"
  tags = [
    // latest
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:latest",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:latest",
    // other tags
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:alpine",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:alpine",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-${SHORT_BUILD_DATE}",
  ]
}

target "hwaccel-alpine" {
  inherits = ["_common", "_alpine_multi"]
  context = "."
  dockerfile = "dockerfile/hwaccel-alpine.Dockerfile"
  tags = [
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-${SHORT_BUILD_DATE}"
  ]
}

target "hwaccel" {
  inherits = ["_common", "_debian_multi"]
  context = "."
  dockerfile = "dockerfile/hwaccel.Dockerfile"
  tags = [
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-${SHORT_BUILD_DATE}"
  ]
}

// develop
target "alpine-develop" {
  inherits = ["alpine", "_develop"]
  tags = [
    // develop tag
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:develop",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:develop",
    // other tags
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-develop",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-develop",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-develop-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:alpine-develop-${SHORT_BUILD_DATE}"
  ]
}

target "hwaccel-alpine-develop" {
  inherits = ["hwaccel-alpine", "_develop"]
  tags = [
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-develop",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-develop",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-develop-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-alpine-develop-${SHORT_BUILD_DATE}"
  ]
}

target "hwaccel-develop" {
  inherits = ["hwaccel", "_develop"]
  tags = [
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-develop",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-develop",
    "ghcr.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-develop-${SHORT_BUILD_DATE}",
    "docker.io/${OWNER_NAME}/${IMAGE_NAME}:hwaccel-develop-${SHORT_BUILD_DATE}"
  ]
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
}