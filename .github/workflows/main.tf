terraform {
    backend "s3" {}

    required_version = ">= 1.2.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
        docker = {
            source  = "kreuzwerker/docker"
            version = "~> 3.0"
        }
    }
}


locals {
    ns = "${var.name}-${var.environment}"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ecr_authorization_token" "token" {}

provider "aws" {
    region = "us-west-2"
}

provider "docker" {
    registry_auth {
        address  = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.current.account_id, data.aws_region.current.name)
        username = data.aws_ecr_authorization_token.token.user_name
        password = data.aws_ecr_authorization_token.token.password
    }
}

module "docker_image" {
    source = "terraform-aws-modules/lambda/aws//modules/docker-build"

    create_ecr_repo = true
    ecr_repo        = local.ns
    image_tag       = var.image_tag
    source_path     = "../../"
}

module "lambda_function_from_container_image" {
    source = "terraform-aws-modules/lambda/aws"

    function_name              = local.ns
    description                = "Ephemeral preview environment for: ${local.ns}"
    create_package             = false
    package_type               = "Image"
    image_uri                  = module.docker_image.image_uri
    architectures              = ["x86_64"]
    create_lambda_function_url = true
}

resource "docker_volume" "database_data" {
    name = "database_data"
}

resource "docker_container" "database" {
  name    = "database"
  image   = "mariadb:${var.db_tag}"
  restart = "unless-stopped"

  ports {
    internal = var.db_port
    external = 33450
  }

  environment {
    MYSQL_DATABASE      = var.db_name
    MYSQL_PASSWORD      = var.db_password
    MYSQL_USER          = var.db_user
    MYSQL_ROOT_PASSWORD = var.db_root_password
  }

  volumes {
    volume_name    = docker_volume.database_data.name
    container_path = "/var/lib/mysql"
  }
}

output "endpoint_url" {
    value = module.lambda_function_from_container_image.lambda_function_url
}
