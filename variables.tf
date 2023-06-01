variable "aws_region" {
  description = "Name of the AWS Region where this is hosted."
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project to create and must be unique as S3 bucket names are global"
}

# Nuclei binary configuration
variable "nuclei_version" {
  description = "Nuclei version to use"
  default     = "2.9.6"
}

variable "nuclei_arch" {
  description = "Nuclei architecture to use"
  default     = "linux_amd64"
}

# Private Templates
variable "github_repository" {
  description = "Github repository to use for templates"
  default     = "nuclei-templates"
}

variable "github_owner" {
  description = "Github owner to use for templates"
  default     = "projectdiscovery"
}

variable "release_tag" {
  description = "Github release tag to use for templates"
  default     = "v9.5.1"
}

variable "github_token" {
  description = "Github token to use for private templates, leave empty if you don't need private templates"
  default     = ""
  sensitive   = true
}

variable "nuclei_timeout" {
  type        = number
  description = "Lambda function timeout"
  default     = 900
}

variable "memory_size" {
  type    = number
  default = 512
}

variable "tags" {
  type = map(string)
  default = {
    "Name" = "nuclei-scanner"
  }
}
