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

############################################
# ECS Maria DB                             #
############################################
// Create a VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16" // CIDR block for the VPC
}

// Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
}

// Create a subnet
resource "aws_subnet" "public-1" {
    vpc_id     = aws_vpc.main.id // ID of the VPC to create the subnet in
    cidr_block = "10.0.1.0/24"   // CIDR block for the subnet
    availability_zone = "${var.region}a"
    tags = {
        Name = "Public Subnet 1"
    }
}

// Create a subnet
resource "aws_subnet" "public-2" {
    vpc_id     = aws_vpc.main.id // ID of the VPC to create the subnet in
    cidr_block = "10.0.2.0/24"   // CIDR block for the subnet
    availability_zone = "${var.region}a"
    tags = {
        Name = "Public Subnet 2"
    }
}

// Create a route table with a route to the internet gateway
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "public1" {
    subnet_id      = aws_subnet.public-1.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
    subnet_id      = aws_subnet.public-2.id
    route_table_id = aws_route_table.public.id
}

// Create a security group
resource "aws_security_group" "main" {
    name   = "main"          // Name of the security group
    vpc_id = aws_vpc.main.id // ID of the VPC to create the security group in

    ingress {
        description = "Allow http traffic"
        from_port   = "80"
        to_port     = "80"
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "Allow https traffic"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0             // Start port for outbound traffic
        to_port     = 0             // End port for outbound traffic
        protocol    = "-1"          // Protocol for outbound traffic
        cidr_blocks = ["0.0.0.0/0"] // CIDR blocks for outbound traffic
    }
}

// Create a network ACL with an ingress rule for HTTPS and a default egress rule
resource "aws_network_acl" "main" {
    vpc_id = aws_vpc.main.id

    ingress {
        rule_no    = 100
        action     = "allow"
        from_port  = 443
        to_port    = 443
        protocol   = "tcp"
        cidr_block = "0.0.0.0/0"
    }

    egress {
        rule_no    = 100
        action     = "allow"
        from_port  = 0
        to_port    = 0
        protocol   = "-1"
        cidr_block = "0.0.0.0/0"
    }
}

// TODO: attempt to move these policies into setup/main.tf or setup/policy.tmpl
// Create an ECS cluster
resource "aws_ecs_cluster" "main" {
    name = "main" // Name of the ECS cluster
}

// Create a security group with ingress rules for MySQL and a default egress rule
resource "aws_security_group" "ecs_task" {
    name   = "ecs_task"      // Name of the security group
    vpc_id = aws_vpc.main.id // ID of the VPC to create the security group in

    ingress {
        from_port   = 3306          // Start port for inbound traffic
        to_port     = 3306          // End port for inbound traffic
        protocol    = "tcp"         // Protocol for inbound traffic
        cidr_blocks = ["0.0.0.0/0"] // CIDR blocks for inbound traffic
    }

    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    #     egress {
    #         from_port   = 0 // Start port for outbound traffic
    #         to_port     = 0 // End port for outbound traffic
    #         protocol    = "-1" // Protocol for outbound traffic
    #         cidr_blocks = ["0.0.0.0/0"] // CIDR blocks for outbound traffic
    #     }
}

resource "aws_security_group" "lambda_sg" {
    name   = "lambda_sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        security_groups = [aws_security_group.ecs_task.id]
    }
}

// Create an ECS task definition for a MariaDB Docker container
resource "aws_ecs_task_definition" "mariadb" {
    family                   = "mariadb"                      // Name of the task definition
    network_mode             = "awsvpc"                       // Network mode for the task
    requires_compatibilities = ["FARGATE"]                    // Launch types required by the task
    cpu                      = "256"                          // Amount of CPU used by the task
    memory                   = "512"                          // Amount of memory used by the task
    execution_role_arn       = data.aws_caller_identity.current.arn // ARN of the IAM role used by the task

    container_definitions = jsonencode([{
        name  = "mariadb",        // Name of the container
        image = "mariadb:10.5.8", // Docker image for the container
        portMappings = [{
            containerPort = 3306, // Port to expose on the container
            hostPort      = 3306, // Port to map to on the host
            protocol      = "tcp" // Protocol for the port mapping
        }],
        environment = [
            {
                name      = "MYSQL_ROOT_PASSWORD", // Environment variable for the root password
                value     = "!ChangeMe!"           // Value of the environment variable
                sensitive = true                   // Whether the environment variable is sensitive
            },
            {
                name      = "MYSQL_DATABASE", // Environment variable for the database name
                value     = "symfony"         // Value of the environment variable
                sensitive = true              // Whether the environment variable is sensitive
            },
            {
                name      = "MYSQL_USER", // Environment variable for the username
                value     = "symfony"     // Value of the environment variable
                sensitive = true          // Whether the environment variable is sensitive
            },
            {
                name      = "MYSQL_PASSWORD", // Environment variable for the password
                value     = "!ChangeMe!"      // Value of the environment variable
                sensitive = true              // Whether the environment variable is sensitive
            }
        ],
        essential = true, // Whether the container is essential
#         logConfiguration = {
#             logDriver = "awslogs", // Log driver for the container
#             options = {
#                 // TODO: fix
#                 "awslogs-group"         = aws_cloudwatch_log_group.ecs.name, // CloudWatch log group for the container logs
#                 "awslogs-region"        = var.region,                    // AWS region for the CloudWatch log group
#                 "awslogs-stream-prefix" = "mariadb"                          // Prefix for the log streams
#             }
#         }
    }])
}

// Create an ECS service for the MariaDB task
resource "aws_ecs_service" "mariadb" {
    name            = "mariadb"                           // Name of the ECS service
    cluster         = aws_ecs_cluster.main.id             // ID of the ECS cluster to create the service in
    task_definition = aws_ecs_task_definition.mariadb.arn // ARN of the task definition to use for the service
    desired_count   = 1                                   // Number of tasks to run in the service
    launch_type     = "FARGATE"                           // Launch type for the service

    network_configuration {
        assign_public_ip = true                             // Whether to assign a public IP to the tasks
        subnets          = [aws_subnet.public-1.id, aws_subnet.public-2.id]    // IDs of the subnets to place the tasks in
        security_groups  = [aws_security_group.ecs_task.id] // IDs of the security groups to associate with the tasks
    }
}

############################################
# Lambda                                   #
############################################

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
        password = data.aws_caller_identity.current.account_id
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

    vpc_security_group_ids = [aws_security_group.lambda_sg.id]
    vpc_subnet_ids         = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

# resource "docker_container" "database" {
#   name    = "database"
#   image   = "mariadb:${var.db_tag}"
#   restart = "unless-stopped"
#
#   ports {
#     internal = var.db_port
#     external = 33450
#   }
#
#     env = [
#         "MYSQL_DATABASE=${var.db_name}",
#         "MYSQL_PASSWORD=${var.db_password}",
#         "MYSQL_USER=${var.db_user}",
#         "MYSQL_ROOT_PASSWORD=${var.db_root_password}"
#     ]
# }

output "endpoint_url" {
    value = module.lambda_function_from_container_image.lambda_function_url
}
