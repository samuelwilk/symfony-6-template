variable "name" {
    type        = string
    description = "name for the resources"
}

variable "environment" {
    type        = string
    description = "environment for the resources"
}

variable "image_tag" {
    type        = string
    description = "container image tag"
}

variable "region" {
    type        = string
    description = "AWS region"
    default     = "us-west-2"
}

variable "db_host" {
    type        = string
    description = "database host"
}

variable "db_name" {
    type        = string
    description = "database name"
}

variable "db_user" {
    type        = string
    description = "database user"
}

variable "db_password" {
    type        = string
    description = "database password"
    sensitive   = true
}

variable "db_root_password" {
    type        = string
    description = "database root password"
    sensitive   = true
}

variable "db_port" {
    type        = number
    description = "database internal port"
    default     = 3306
}
