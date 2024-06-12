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
    description = "The region Terraform deploys your instances"
    type        = string
    default     = "us-east-2"
}
