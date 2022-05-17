# All generated input variables will be of 'string' type as this is how Packer JSON
# views them; you can change their type later on. Read the variables type
# constraints documentation
# https://www.packer.io/docs/templates/hcl_templates/variables#type-constraints for more info.
variable "ami_description" {
  type    = string
  default = ""
}

variable "ami_name" {
  type    = string
  default = ""
}

variable "aws_access_key" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "aws_secret_key" {
  type    = string
  default = ""
}

variable "aws_subnet" {
  type    = string
  default = ""
}

variable "aws_vpc" {
  type    = string
  default = ""
}

variable "builder_name" {
  type    = string
  default = ""
}

variable "instance_type" {
  type    = string
  default = "t2.medium"
}

variable "tarball" {
  type    = string
  default = ""
}

variable "username" {
  type    = string
  default = "pulsys"
}

# Read the documentation for data blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/data
# Read the documentation for the Amazon AMI Data Source here:
# https://www.packer.io/docs/datasources/amazon/ami
data "amazon-ami" "ubuntu-focal" {
  access_key = "${var.aws_access_key}"
  filters = {
    name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
  region      = "${var.aws_region}"
  secret_key  = "${var.aws_secret_key}"
}

# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

# source. Read the documentation for source blocks here:
# this is for a globus VM only. to generalize remove globus below
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "amazon-ebs" "ubuntu-focal" {
  access_key     = "${var.aws_access_key}"
  ami_name       = "ubuntu-globus-ami-pul_${local.timestamp}"
  instance_type  = "${var.instance_type}"
  region         = "${var.aws_region}"
  secret_key     = "${var.aws_secret_key}"
  source_ami     = "${data.amazon-ami.ubuntu-focal.id}"
  ssh_username   = "pulsys"
  user_data_file = "./config/defaults.cfg"
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.amazon-ebs.ubuntu-focal"]

  provisioner "file" {
    destination = "/tmp/defaults.cfg"
    source      = "./config/defaults.cfg"
  }

  provisioner "shell" {
    inline = ["sudo mv /tmp/defaults.cfg /etc/cloud/cloud.cfg.d/defaults.cfg"]
  }

  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "scripts/install_tools.sh"
  }


  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "scripts/setup.sh"
  }

  provisioner "ansible" {
    playbook_file = "scripts/dev_user_add.yml"
  }

  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "scripts/cleanup.sh"
  }

}
