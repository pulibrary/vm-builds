# --- VARIABLES ---
variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version, e.g. \"22.04\""
  default     = "22.04"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "username" {
  type    = string
  default = "pulsys"
}

