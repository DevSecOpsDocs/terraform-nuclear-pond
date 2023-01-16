variable "project_name" {
  description = "Name of the project to create and must be unique as S3 bucket names are global"
}

# You should check the latest version of Nuclei
# https://github.com/projectdiscovery/nuclei/releases/
variable "nuclei_version" {
  description = "Nuclei version to use"
  default     = "2.8.6"
}

# You can also use private templates by download zip of your repo, copy url from downloaded file, and paste the url in here including the token
variable "nuclei_templates_url" {
  description = "Nuclei templates url to use"
  sensitive   = true
  default     = "https://github.com/projectdiscovery/nuclei-templates/archive/refs/tags/v9.3.4.zip"
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
  default     = "v9.3.4"
}

variable "github_token" {
  description = "Github token to use for private templates, leave empty if you don't need private templates"
  default     = ""
  sensitive   = true
}

variable "nuclei_arch" {
  description = "Nuclei architecture to use"
  default     = "linux_amd64"
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