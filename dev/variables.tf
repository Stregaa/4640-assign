# Terraform variables

# API token
variable "do_token" {
  type = string
  default = "dop_v1_3033c6d92798ef47e91adb1223041453f1117db48030d30dec722f2f54c97368"
}

# set default region to sfo3
variable "region" {
  type = string
  default = "sfo3"
}

# set default droplet count
variable "droplet_count" {
  type = number
  default = 2
}

# set default image
variable "image" {
  type = string
  default = "rockylinux-9-x64"
}

# set default size
variable "size" {
  type = string
  default = "s-1vcpu-512mb-10gb"
}
