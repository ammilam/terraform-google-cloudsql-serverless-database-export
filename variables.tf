variable "backups_resource_project_id" {
  type        = string
  description = "Project to create database backup resources in, if backups_bucket is not specified a backup bucket will be created here as well"
}

variable "location" {
  type = string
}

variable "database_project_id" {
  type        = string
  description = "Project containing the database"
}

variable "database_instance" {
  type        = string
  description = "Database instance name"
}

variable "database_name" {
  type        = string
  description = "Database name"
}

variable "schedule" {
  type        = string
  default     = "0 0 * * 4"
  description = "Cron for backup schedule"
}

variable "cloudfunction_service_account" {
  type        = string
  description = "ServiceAccount to assign to the backups CloudFunction"
}

variable "max_backup_age_days" {
  type        = number
  default     = 365
  description = "Max number of days to keep an exported backup"
}

variable "backups_bucket" {
  type        = string
  default     = ""
  description = "Bucket to export backups to, if not provided a bucket will be created"
}