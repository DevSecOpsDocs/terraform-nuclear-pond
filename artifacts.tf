provider "github" {
  token = var.github_token
}

# Download nuclei binary and templates
resource "null_resource" "always_run" {  
 triggers = {
    timestamp = "${timestamp()}"  
  }
}

# Download nuclei binary and templates
resource "null_resource" "download_nuclei" {  
  depends_on          = [null_resource.always_run]
  triggers = {
    version = var.nuclei_version     
  
  }

  provisioner "local-exec" {
    #command = "curl -o ${path.module}/src/nuclei.zip -L https://github.com/projectdiscovery/nuclei/releases/download/v${var.nuclei_version}/nuclei_${var.nuclei_version}_${var.nuclei_arch}.zip"    
    # use custom nuclei.zip for right now.... TODO: fix me!
    command = "cp /home/vnc/nuclei.zip ${path.module}/src/nuclei.zip"
  }
}

resource "null_resource" "download_templates" {
  depends_on = [null_resource.always_run]
  triggers = {
    version = var.release_tag    
  }

  provisioner "local-exec" {
    command = "curl -o ${path.module}/src/nuclei-templates.zip -L https://github.com/projectdiscovery/nuclei-templates/archive/refs/tags/${var.release_tag}.zip"
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

# Nuclei configuration files
data "archive_file" "nuclei_config" {
  type        = "zip"
  source_dir  = "${path.module}/config"
  output_path = "nuclei-configs.zip"
}

resource "aws_s3_object" "upload_config" {
  depends_on = [data.archive_file.nuclei_config]
  bucket = aws_s3_bucket.bucket.id
  key    = "nuclei-configs.zip"
  source = "${path.module}/nuclei-configs.zip"
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