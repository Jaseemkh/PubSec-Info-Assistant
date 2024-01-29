variable "randomString" {
  type = string
}

variable "requireWebsiteSecurityMembership" {
  type = bool
  default = false
}

variable "webAppSuffix" {
  type        = string
}

variable "isInAutomation" {
  type    = bool
  default = false
}