variable "instance_name" {
  description = "The name of the EC2 instance"
  type        = string
  default     = "ExampleAppServerInstance"
}

variable "github_org" {
  description = "The name of the GitHub organization"
  type        = string
  default     = "samuelwilk"

}

variable "github_repo" {
  description = "The name of the GitHub repository"
  type        = string
  default     = "symfony-6-template"
}

variable "region" {
  description = "aws region"
  type        = string
  default     = "us-west-2"
}
