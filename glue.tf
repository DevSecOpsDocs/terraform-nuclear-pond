resource "aws_glue_catalog_database" "database" {
  name        = "nuclei_db"
  description = "Database for nuclei findings"
}

resource "aws_glue_catalog_table" "table" {
  name          = "findings_db"
  database_name = aws_glue_catalog_database.database.name
  table_type    = "EXTERNAL_TABLE"

  storage_descriptor {
    location = "s3://${aws_s3_bucket.bucket.id}/findings/"

    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    columns {
      name = "extracted-results"
      type = "array<string>"
    }
    columns {
      name = "host"
      type = "string"
    }
    columns {
      name = "info"
      type = "struct<author:array<string>,classification:string,description:string,name:string,reference:array<string>,severity:string,tags:array<string>>"
    }
    columns {
      name = "metadata"
      type = "struct<shodan-query:string,verified:string>"
    }
    columns {
      name = "matched-at"
      type = "string"
    }
    columns {
      name = "matched-line"
      type = "string"
    }
    columns {
      name = "matcher-status"
      type = "string"
    }
    columns {
      name = "template-id"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "matcher-name"
      type = "string"
    }
    columns {
      name = "curl-command"
      type = "string"
    }
    columns {
      name = "ip"
      type = "string"
    }
    columns {
      name = "template-url"
      type = "string"
    }
    columns {
      name = "template"
      type = "string"
    }

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = "1"
        "serialization.null.format" = "null"
      }
    }
  }

  partition_keys {
    name = "dt"
    type = "string"
  }

  parameters = {
    "EXTERNAL"                    = "TRUE"
    "compressionType"             = "none"
    "classification"              = "json"
    "typeOfData"                  = "file"
    "projection.enabled"          = "true"
    "projection.dt.type"          = "date"
    "projection.dt.format"        = "yyyy/MM/dd/HH"
    "projection.dt.interval"      = "1"
    "projection.dt.interval.unit" = "HOURS"
    "projection.dt.range"         = "NOW-3MONTHS,NOW"
    "storage.location.template"   = "s3://${aws_s3_bucket.bucket.id}/findings/$${dt}"
  }
}