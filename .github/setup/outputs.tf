# output "instance_id" {
#   description = "ID of the EC2 instance"
#   value       = aws_instance.app_server.id
# }
# output "instance_public_ip" {
#   description = "Public IP address of the EC2 instance"
#   value       = aws_instance.app_server.public_ip
# }
output "AWS_ROLE" {
  value = aws_iam_role.github_actions.arn
}

output "TF_BACKEND_S3_BUCKET" {
  value = module.terraform_state_s3_bucket.s3_bucket_id
}

output "AWS_REGION" {
  value = data.aws_region.current.name
}
