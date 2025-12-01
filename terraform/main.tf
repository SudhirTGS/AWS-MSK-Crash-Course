# Main Terraform Configuration for MSK Cluster - Hardcoded Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "msk-dev-user"  # This tells Terraform to use your AWS CLI profile
  
  # Optional: Validate you're deploying to the correct account
  allowed_account_ids = ["290384550501"]
  
  # Default tags applied to all resources
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "msk-crash-course"
      ManagedBy   = "Terraform"
      Owner       = "Development Team"
      Purpose     = "MSK Learning and Testing"
    }
  }
}

# Data Sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# No local variables - everything hardcoded directly in resources

# VPC
resource "aws_vpc" "msk_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "msk_igw" {
  vpc_id = aws_vpc.msk_vpc.id

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-igw"
  }
}

# MSK Subnets - 3 subnets for basic setup (public IPs, no NAT gateways)
resource "aws_subnet" "msk_subnets" {
  count             = 3
  vpc_id            = aws_vpc.msk_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Basic setup - subnets have public IPs (no NAT gateways)
  map_public_ip_on_launch = true

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-subnet-${count.index + 1}"
    Type        = "Public"
    Tier        = "MSK"
  }
}

# Route Table for MSK Subnets
resource "aws_route_table" "msk_rt" {
  vpc_id = aws_vpc.msk_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.msk_igw.id
  }

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-rt"
  }
}

# Route Table Associations for MSK Subnets
resource "aws_route_table_association" "msk_rta" {
  count          = 3
  subnet_id      = aws_subnet.msk_subnets[count.index].id
  route_table_id = aws_route_table.msk_rt.id
}

# Security Group for MSK Cluster
resource "aws_security_group" "msk_sg" {
  name        = "dev-msk-crash-course-msk-sg"
  description = "Security group for MSK cluster"
  vpc_id      = aws_vpc.msk_vpc.id

  # Kafka Plaintext (9092)
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_vpc.cidr_block]
    description = "Kafka plaintext"
  }

  # Kafka TLS (9094)
  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_vpc.cidr_block]
    description = "Kafka TLS"
  }

  # Kafka SASL/IAM (9098)
  ingress {
    from_port   = 9098
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_vpc.cidr_block]
    description = "Kafka SASL/IAM"
  }

  # Zookeeper (2181)
  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_vpc.cidr_block]
    description = "Zookeeper"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-msk-sg"
  }
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk_logs" {
  name              = "/aws/msk/dev-msk-crash-course-cluster"
  retention_in_days = 7

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-msk-logs"
  }
}

# MSK Configuration
resource "aws_msk_configuration" "msk_config" {
  kafka_versions = ["3.6.0"]
  name           = "dev-msk-crash-course-cluster-config"
  description    = "MSK configuration for dev environment"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
default.replication.factor=3
min.insync.replicas=2
num.partitions=3
log.retention.hours=48
unclean.leader.election.enable=false
PROPERTIES
}

# MSK Cluster
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name           = "dev-msk-crash-course-cluster"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3
  enhanced_monitoring    = "PER_BROKER"

  configuration_info {
    arn      = aws_msk_configuration.msk_config.arn
    revision = aws_msk_configuration.msk_config.latest_revision
  }

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = aws_subnet.msk_subnets[*].id
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
    unauthenticated = true
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_logs.name
      }
    }
  }

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-cluster"
  }
}

# ----------------------------------------------------------------------------
# Kafka Client EC2 Instance
# -----------------------------------------------------------------------------

# Security Group for the Kafka Client EC2 instance
resource "aws_security_group" "kafka_client_sg" {
  name        = "dev-msk-crash-course-client-sg"
  description = "Allow SSH access to Kafka client instance"
  vpc_id      = aws_vpc.msk_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: This allows SSH from anywhere. For production, restrict this to your IP address, e.g., ["YOUR_IP/32"].
    description = "Allow SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "dev-msk-crash-course-client-sg"
  }
}

# EC2 instance to act as a Kafka client
resource "aws_instance" "kafka_client" {
  ami                    = data.aws_ami.amazon_linux_2.id # Dynamically find the latest Amazon Linux 2
  instance_type          = "t3.small"  # t3.small (2GB RAM) - Good balance of cost and performance
  subnet_id              = aws_subnet.msk_subnets[0].id
  vpc_security_group_ids = [aws_security_group.msk_sg.id, aws_security_group.kafka_client_sg.id]
  key_name               = "msk-dev-keypair" # IMPORTANT: Replace with the name of your EC2 Key Pair

  # User data to install Kafka tools on boot
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java-11-amazon-corretto
              
              # Install Kafka
              wget https://archive.apache.org/dist/kafka/3.6.0/kafka_2.13-3.6.0.tgz
              tar -xzf kafka_2.13-3.6.0.tgz
              mv kafka_2.13-3.6.0 /opt/kafka
              
              # Set up environment variables for ec2-user (using plaintext for better memory efficiency)
              echo 'export PATH=$PATH:/opt/kafka/bin' >> /home/ec2-user/.bashrc
              echo "export BOOTSTRAP_SERVERS=${aws_msk_cluster.msk_cluster.bootstrap_brokers}" >> /home/ec2-user/.bashrc
              echo 'export KAFKA_HEAP_OPTS="-Xmx512M -Xms256M"' >> /home/ec2-user/.bashrc
              source /home/ec2-user/.bashrc
              EOF

  tags = {
    Name = "dev-msk-crash-course-kafka-client-small-v2"
  }
}

# ----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "kafka_client_public_ip" {
  description = "Public IP address of the Kafka client EC2 instance."
  value       = aws_instance.kafka_client.public_ip
}

output "msk_cluster_bootstrap_brokers_tls" {
  description = "TLS bootstrap broker string for the MSK cluster."
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
}

output "ssh_command_to_client" {
  description = "Command to SSH into the Kafka client instance."
  value       = "ssh -i \"msk-dev-keypair.pem\" ec2-user@${aws_instance.kafka_client.public_ip}"
}

