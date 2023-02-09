variable "ssh_password" {
  type = "string"
  default = "ubuntu"
  sensitive = true
}

variable "initial_os_username" {
  type = "string"
  default = "pulsys"
  sensitive = true
}

variable "initial_os_password" {
  type = "string"
  default = "pulsys"
  sensitive = true
}
