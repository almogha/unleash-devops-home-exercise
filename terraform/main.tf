provider "aws" {
  region = "us-west-2"  # Change to your preferred AWS region
}

# Create an ECS Cluster
resource "aws_ecs_cluster" "example" {
  name = "my-fargate-cluster"
}

# Create an IAM role for the ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attach the required policies to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a security group for the ECS tasks
resource "aws_security_group" "ecs_security_group" {
  name   = "ecs-security-group"
  vpc_id = aws_vpc.main.id  # Make sure to reference your VPC ID

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the ECS task definition
resource "aws_ecs_task_definition" "example" {
  family                   = "my-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"       # 0.25 vCPU
  memory                   = "512"       # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "my-app"
    image     = "var.docker_username/unleash-app:var.image_tag" 
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

# Create an ECS service to run the task definition on Fargate
resource "aws_ecs_service" "example" {
  name            = "my-fargate-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.main.*.id  # Ensure you reference the correct subnets
    security_groups = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }
}

# VPC and Subnets for the ECS service
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  count = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

data "aws_availability_zones" "available" {}
