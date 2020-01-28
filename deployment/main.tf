# -----------------------------------------------------------------------------
# System config:

# Configure AWS provider
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# -----------------------------------------------------------------------------
# Configure ECR:
#   - ECR
#   - Login docker

# Create AWS ECR repository
resource "aws_ecr_repository" "repository-001" {
  name = var.aws_ecr_repository_name
}

# Login docker to AWS ECR repository
resource "null_resource" "docker_login" {
  provisioner "local-exec" {
    command = "$(aws ecr get-login --no-include-email --region ${var.aws_region})"
  }
  depends_on = [aws_ecr_repository.repository-001]
}

# -----------------------------------------------------------------------------
# Configure Docker:
#   - Build
#   - Tag
#   - Push

# Build docker image
resource "null_resource" "docker_build" {
  provisioner "local-exec" {
    command = "cd ../ && docker build -t ${var.aws_ecr_repository_name} -f dockerfile --rm ."
  }
  # TODO: create dostroy action
  #provisioner "local-exec" {
  #  when    = destroy
  #  command = "docker rmi ${var.aws_ecr_repository_name}"
  #}
  depends_on = [null_resource.docker_login]
}

# Tag docker image
resource "null_resource" "docker_tag" {
  provisioner "local-exec" {
    command = "docker tag ${var.aws_ecr_repository_name} ${aws_ecr_repository.repository-001.repository_url}"
  }
  depends_on = [null_resource.docker_build]
}

# Push docker container to AWS ECR repository
resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.repository-001.repository_url}"
  }
  depends_on = [null_resource.docker_tag]
}

# -----------------------------------------------------------------------------
# Configure Network:
#   - VPC
#   - Subnets
#   - Internet gateway
#   - Route table
#   - Route table with subnet association

# Create VPC for cluster
resource "aws_vpc" "vpc-001" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Flask helloworld VPC"
  }
}

# Create VPC first subnet for docker conteiners
resource "aws_subnet" "subnet-001" {
  vpc_id            = aws_vpc.vpc-001.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Flask helloworld subnet-001"
  }
}

# Create VPC first subnet for docker conteiners
resource "aws_subnet" "subnet-002" {
  vpc_id            = aws_vpc.vpc-001.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Flask helloworld subnet-002"
  }
}

# Create Internet Gateway for VPC
resource "aws_internet_gateway" "igw-001" {
  vpc_id = aws_vpc.vpc-001.id

  tags = {
    Name = "Flask helloworld igw-001"
  }
}

# Create Route Table
resource "aws_route_table" "rt-001" {
  vpc_id = aws_vpc.vpc-001.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-001.id
  }

  tags = {
    Name = "Flask helloworld rt-001"
  }
}

# Create Route Table Association subnet-001
resource "aws_route_table_association" "rta-001" {
  subnet_id      = aws_subnet.subnet-001.id
  route_table_id = aws_route_table.rt-001.id
}

# Create Route Table Association subnet-002
resource "aws_route_table_association" "rta-002" {
  subnet_id      = aws_subnet.subnet-002.id
  route_table_id = aws_route_table.rt-001.id
}

# -----------------------------------------------------------------------------
# Configure Security:
#   - Security groups
#   - IAM Role

# Create security group to allow http traffic
resource "aws_security_group" "allow-http" {
  name        = "Allow HTTP"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.vpc-001.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP"
  }
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# -----------------------------------------------------------------------------
# Configure ALB:
#   - ALB
#   - Target Group
#   - Listener

# Create Load Balancer
resource "aws_lb" "lb-001" {
  name               = "Flask-helloworld-lb-001"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow-http.id]
  subnets            = [
    aws_subnet.subnet-001.id,
    aws_subnet.subnet-002.id
  ]

  depends_on = [aws_internet_gateway.igw-001]
}

# Create ALB target group
resource "aws_lb_target_group" "tg-001" {
  name        = "Flask-helloworld-tg-001"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-001.id
  target_type = "ip"
}

# Create ALB listener
resource "aws_lb_listener" "listener-001" {
  load_balancer_arn = aws_lb.lb-001.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg-001.id
    type             = "forward"
  }
}

# -----------------------------------------------------------------------------
# Configure ECS:
#   - ECS Cluster
#   - Service
#   - Task definition

# Create ECS cluster
resource "aws_ecs_cluster" "cluster-001" {
  name = "flask-helloworld-cluster"
}

# Create Service
resource "aws_ecs_service" "service-001" {
  name            = "flask-helloworld-service"
  cluster         = aws_ecs_cluster.cluster-001.id
  task_definition = aws_ecs_task_definition.td-001.arn
  desired_count   = 1
  deployment_minimum_healthy_percent = 50
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.allow-http.id]
    subnets          = [aws_subnet.subnet-001.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg-001.id
    container_name   = "flask-helloworld-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.listener-001]
}

# Create Task Definition
resource "aws_ecs_task_definition" "td-001" {
  family                   = "flask-helloworld-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

  # TODO: put container definition to separate file
  container_definitions    = <<EOF
[
  {
    "name": "flask-helloworld-container",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
    "image": "${aws_ecr_repository.repository-001.repository_url}",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
EOF
}

