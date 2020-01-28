variable "aws_region" {
  description = "AWS region to launch services."
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile for authentication."
  default     = "default"
}

variable "aws_ecr_repository_name" {
  description = "AWS ECR repository name for storing conatiners."
  default     = "flask-helloworld-repository"
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "512"
}
