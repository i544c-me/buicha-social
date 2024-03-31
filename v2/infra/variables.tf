variable "rds_username" {
  type      = string
  sensitive = true
}

variable "rds_password" {
  type      = string
  sensitive = true
}

variable "admin_ips" {
  type      = list(string)
  sensitive = true
}

variable "meilisearch_master_key" {
  type      = string
  sensitive = true
}
