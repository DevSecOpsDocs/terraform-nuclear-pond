#!/bin/sh
terraform taint aws_lambda_function.function
rm src/nuclei.zip
rm src/nuclei-templates.zip
rm lambda.zip
terraform taint aws_s3_object.upload_nuclei
terraform taint aws_s3_object.upload_templates
terraform taint aws_s3_object.upload_config
terraform taint aws_lambda_layer_version.layer
terraform taint aws_lambda_layer_version.templates_layer
terraform taint aws_lambda_layer_version.config_layer