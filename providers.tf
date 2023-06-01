# This is the "default" provider that is used assume the roles in the
# other providers.  It uses the credentials of the caller.  It is also
# used to assume the roles required to access remote state in the
# Terraform backend.
provider "aws" {
  default_tags {
    tags = var.tags
  }
  region = var.aws_region
}

# This provider assumes a role so that it can retrieve some
# information about the AWS Organization from the master account.
provider "aws" {
  alias = "read_organization_information"
  default_tags {
    tags = var.tags
  }
  profile = "read_organization_information"
  region = var.aws_region
}

