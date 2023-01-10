variable "project_name" {
  description = "Name of the project to create and must be unique as S3 bucket names are global"
}

# You should check the latest version of Nuclei
# https://github.com/projectdiscovery/nuclei/releases/
variable "nuclei_version" {
  description = "Nuclei version to use"
  default     = "2.8.6"
}

variable "nuclei_arch" {
  description = "Nuclei architecture to use"
  default     = "linux_amd64"
}

variable "nuclei_timeout" {
  type    = number
  description = "Lambda function timeout"
  default = 900
}

variable "memory_size" {
  type    = number
  default = 512
}

variable "tags" {
  type = map(string)
  default = {
    "Name"  = "nuclei-scanner"
    "Owner" = "johnny"
  }
}