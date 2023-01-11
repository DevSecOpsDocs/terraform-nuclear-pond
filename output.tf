output "function_name" {
  value = aws_lambda_function.function.arn
}

output "dynamodb_state_table" {
  value = aws_dynamodb_table.scan_state_table.arn
}