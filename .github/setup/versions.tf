terraform {
  cloud {
    organization = "GitGud_testing"
    workspaces {
      name = "symfony-6"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}
