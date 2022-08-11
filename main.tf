# pubsub topic used to invoke the backup CloudFunction
resource "google_pubsub_topic" "backups" {
  project = var.backups_resource_project_id
  name    = "${var.database_name}-backups"
}

# zip CloudFunction source code
data "archive_file" "cf_code" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/files/index.zip"
}

# create a bucket to store CloudFunction source code
resource "google_storage_bucket" "cf_bucket" {
  name                        = "${var.database_name}-bsc-${var.backups_resource_project_id}"
  project                     = var.backups_resource_project_id
  uniform_bucket_level_access = true
  force_destroy               = true
  location                    = var.location
}

# upload CloudFunction source code to bucket
resource "google_storage_bucket_object" "archive" {
  name   = "backups/index-${data.archive_file.cf_code.output_md5}.zip"
  bucket = google_storage_bucket.cf_bucket.name
  source = data.archive_file.cf_code.output_path
}

locals {
  bucket_name = "${var.database_name}-backups-${var.backups_resource_project_id}"
}
# bucket for backups, deletes objects older than 30 days
resource "google_storage_bucket" "backups" {
  name                        = local.bucket_name
  count                       = var.backups_bucket == "" ? 1 : 0
  project                     = var.backups_resource_project_id
  uniform_bucket_level_access = true
  force_destroy               = true
  location                    = var.location
  lifecycle_rule {
    condition {
      age = var.max_backup_age_days
    }
    action {
      type = "Delete"
    }
  }
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30
    }
  }
}

###########################################
# database instance service account roles #
###########################################

# gets database info to pull service account
data "google_sql_database_instance" "db_data" {
  project = var.database_project_id
  name    = var.database_instance
}

# bucket level role that allows the database to export its data to it
resource "google_storage_bucket_iam_member" "bucket_legacy_writer" {
  bucket = var.backups_bucket == "" ? local.bucket_name : var.backups_bucket
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${data.google_sql_database_instance.db_data.service_account_email_address}"
}

locals {
  bucket_url                    = var.backups_bucket == "" ? "gs//${local.bucket_name}" : "gs://${var.backups_bucket}"
  application_backup_bucket_url = "${local.bucket_url}/cloud-sql-exports/${terraform.workspace != "default" ? "${terraform.workspace}/" : "/"}${var.database_name}"
}

# backup cloud function
resource "google_cloudfunctions_function" "backups" {
  name                  = "${var.database_name}-backups"
  description           = "Cloud Function that backs up ${var.database_name}'s CloudSQL Database"
  runtime               = "nodejs14"
  project               = var.backups_resource_project_id
  available_memory_mb   = 1024
  source_archive_bucket = google_storage_bucket.cf_bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  timeout               = 60
  entry_point           = "backup"
  region                = var.location
  max_instances         = 1
  service_account_email = var.cloudfunction_service_account
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.backups.name
  }
  environment_variables = {
    PROJECT_ID          = var.database_project_id
    DATABASE_INSTANCE   = var.database_instance
    DATABASE_NAME       = var.database_name
    BACKUP_PATH         = local.application_backup_bucket_url
    SERVICE_ACCOUNT     = var.cloudfunction_service_account
    TERRAFORM_WORKSPACE = terraform.workspace
  }
}

# cloud scheduler job that invokes the pubsub topic that triggers the CloudFunction
resource "google_cloud_scheduler_job" "backups" {
  name        = "${var.database_name}-backups"
  description = "Invokes Artifactory Database Backups"
  project     = var.backups_resource_project_id
  region      = var.location
  schedule    = var.schedule
  time_zone   = "America/Chicago"

  pubsub_target {
    topic_name = google_pubsub_topic.backups.id
    data       = base64encode("backup")
  }
}