variable "nuclei_version" {
  description = "Nuclei version to use"
  default     = "2.8.3"
}

variable "nuclei_arch" {
  description = "Nuclei architecture to use"
  default     = "linux_amd64"
}

variable "project_name" {
  description = "Name of the project"
  default     = "nuclei-scanner"
}

variable "nuclei_timeout" {
  type    = number
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