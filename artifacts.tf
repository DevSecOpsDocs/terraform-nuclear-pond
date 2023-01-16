# Download nuclei binary and templates
resource "null_resource" "download_nuclei" {
  triggers = {
    version = var.nuclei_version
  }

  provisioner "local-exec" {
    command = "curl -o ${path.module}/src/nuclei.zip -L https://github.com/projectdiscovery/nuclei/releases/download/v${var.nuclei_version}/nuclei_${var.nuclei_version}_${var.nuclei_arch}.zip"
  }
}

provider "github" {
  token = var.github_token
}

data "github_release" "templates" {
  repository = var.github_repository
  owner      = var.github_owner
  tag_name   = var.release_tag
}

resource "null_resource" "download_templates" {
  triggers = {
    version = var.release_tag
  }

  provisioner "local-exec" {
    command = "curl -o ${path.module}/src/nuclei-templates.zip -L ${data.github_release.templates.zipball_url}"
  }
}

# Upload them to s3
resource "aws_s3_object" "upload_nuclei" {
  depends_on = [null_resource.download_nuclei]

  bucket = aws_s3_bucket.bucket.id
  key    = "nuclei.zip"
  source = "${path.module}/src/nuclei.zip"
}

resource "aws_s3_object" "upload_templates" {
  depends_on = [null_resource.download_templates]

  bucket = aws_s3_bucket.bucket.id
  key    = "nuclei-templates.zip"
  source = "${path.module}/src/nuclei-templates.zip"
}


# Nuclei Config File `-config /opt/nuclei-config.yaml`
data "archive_file" "report_config" {
  type        = "zip"
  source_file = "config/report-config.yaml"
  output_path = "report-config.zip"
}

resource "aws_s3_object" "upload_config" {
  bucket = aws_s3_bucket.bucket.id
  key    = "report-config.zip"
  source = "${path.module}/report-config.zip"
}

# Build the lambda function to execute binary
resource "null_resource" "build" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/src && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o main"
  }
}

data "archive_file" "zip" {
  depends_on  = [null_resource.build]
  type        = "zip"
  source_file = "src/main"
  output_path = "lambda.zip"
}