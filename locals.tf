# ------------------------------------------------------------------------------
# Retrieve the caller identity for the current assessment in order to
# get the associated Account ID.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "assessment" {
}

# ------------------------------------------------------------------------------
# Retrieve the information for all accouts in the organization.  This is used
# to lookup the Users account ID for use in the assume role policy.
# ------------------------------------------------------------------------------
data "aws_organizations_organization" "cool" {
  provider = aws.read_organization_information
}

# ------------------------------------------------------------------------------
# Retrieve the default tags for the assessment provider.  These are
# used to create volume tags for EC2 instances, since volume_tags does
# not yet inherit the default tags from the provider.  See
# hashicorp/terraform-provider-aws#19188 for more details.
# ------------------------------------------------------------------------------
data "aws_default_tags" "assessment" {
}

# ------------------------------------------------------------------------------
# Evaluate expressions for use throughout this configuration.
# ------------------------------------------------------------------------------
locals {
  # The account ID for this assessment
  assessment_account_id = data.aws_caller_identity.assessment.account_id

  # Look up assessment account name from AWS organizations provider
  assessment_account_name = [
    for account in data.aws_organizations_organization.cool.accounts :
    account.name
    if account.id == local.assessment_account_id
  ][0]

  # Determine assessment account type based on account name.
  #
  # The account name format is "ACCOUNT_NAME (ACCOUNT_TYPE)" - for
  # example, "env0 (Production)".
  assessment_account_type = length(regexall("\\(([^()]*)\\)", local.assessment_account_name)) == 1 ? regex("\\(([^()]*)\\)", local.assessment_account_name)[0] : "Unknown"

  # The Terraform workspace name for this assessment
  assessment_workspace_name = replace(replace(lower(local.assessment_account_name), "/[()]/", ""), " ", "-")

  # Determine the ID of the corresponding Images account
  images_account_id = [
    for account in data.aws_organizations_organization.cool.accounts :
    account.id
    if account.name == "Images (${local.assessment_account_type})"
  ][0]
}
