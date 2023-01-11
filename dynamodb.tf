resource "aws_dynamodb_table" "scan_state_table" {
  name         = "${var.project_name}-server-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "scan_id"
  attribute {
    name = "scan_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = var.tags
}