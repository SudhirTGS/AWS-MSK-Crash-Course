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

# Public Subnet for EC2 Client (SSH access)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.msk_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-public-subnet"
    Type        = "Public"
    Tier        = "EC2"
  }
}

# Private Subnets for MSK Brokers (3 subnets across 3 AZs)
resource "aws_subnet" "msk_private_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.msk_vpc.id
  cidr_block              = "10.0.${count.index + 10}.0/24"  # 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false  # Private - no public IPs

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Learning and Testing"
    Name        = "dev-msk-crash-course-msk-private-subnet-${count.index + 1}"
    Type        = "Private"
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

# Route Table Associations are defined later with NAT Gateway configuration

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
    client_subnets  = aws_subnet.msk_private_subnets[*].id  # Use private subnets only
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
  subnet_id              = aws_subnet.public_subnet.id  # EC2 in public subnet for SSH access
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
# MSK Connect - NewRelic Sink Connector
# ----------------------------------------------------------------------------

# IAM Role for MSK Connect
resource "aws_iam_role" "msk_connect_role" {
  name = "dev-msk-connect-newrelic-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "kafkaconnect.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Connect service role"
    Name        = "dev-msk-connect-newrelic-role"
  }
}

# IAM Policy for MSK Connect to access MSK Cluster
resource "aws_iam_policy" "msk_connect_msk_policy" {
  name        = "dev-msk-connect-msk-access-policy"
  description = "Allow MSK Connect to access MSK cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka:GetBootstrapBrokers"
        ]
        Resource = aws_msk_cluster.msk_cluster.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_cluster.msk_cluster.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "arn:aws:kafka:us-east-1:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.msk_cluster.cluster_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:us-east-1:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.msk_cluster.cluster_name}/*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Connect MSK access policy"
  }
}

# IAM Policy for MSK Connect to write logs to CloudWatch
resource "aws_iam_policy" "msk_connect_logs_policy" {
  name        = "dev-msk-connect-cloudwatch-logs-policy"
  description = "Allow MSK Connect to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/msk-connect/*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Connect CloudWatch logs policy"
  }
}

# IAM Policy for MSK Connect to create ENIs (network interfaces)
resource "aws_iam_policy" "msk_connect_vpc_policy" {
  name        = "dev-msk-connect-vpc-policy"
  description = "Allow MSK Connect to create network interfaces"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Connect VPC policy"
  }
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "msk_connect_msk_attach" {
  role       = aws_iam_role.msk_connect_role.name
  policy_arn = aws_iam_policy.msk_connect_msk_policy.arn
}

resource "aws_iam_role_policy_attachment" "msk_connect_logs_attach" {
  role       = aws_iam_role.msk_connect_role.name
  policy_arn = aws_iam_policy.msk_connect_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "msk_connect_vpc_attach" {
  role       = aws_iam_role.msk_connect_role.name
  policy_arn = aws_iam_policy.msk_connect_vpc_policy.arn
}

# CloudWatch Log Group for MSK Connect
resource "aws_cloudwatch_log_group" "msk_connect_logs" {
  name              = "/aws/msk-connect/kafka-sink-nr-connector"
  retention_in_days = 7

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "MSK Connect NewRelic connector logs"
    Name        = "kafka-sink-nr-connector-logs"
  }
}

# Security Group for MSK Connect
resource "aws_security_group" "msk_connect_sg" {
  name        = "dev-msk-connect-sg"
  description = "Security group for MSK Connect connector"
  vpc_id      = aws_vpc.msk_vpc.id

  # Allow outbound to MSK cluster (all Kafka ports)
  egress {
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_vpc.cidr_block]
    description = "Access to MSK cluster"
  }

  # Allow outbound HTTPS for NewRelic API
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access to NewRelic API"
  }

  # Allow all outbound (for general connectivity)
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
    Purpose     = "MSK Connect security group"
    Name        = "dev-msk-connect-sg"
  }
}

# MSK Connect Connector - NewRelic Sink
resource "aws_mskconnect_connector" "newrelic_sink" {
  name = "kafka-sink-nr-connector"

  kafkaconnect_version = "2.7.1"

  capacity {
    autoscaling {
      mcu_count        = 1
      min_worker_count = 1
      max_worker_count = 2

      scale_in_policy {
        cpu_utilization_percentage = 20
      }

      scale_out_policy {
        cpu_utilization_percentage = 80
      }
    }
  }

  connector_configuration = {
    "connector.class"                  = "com.example.newrelic.NewRelicSinkConnector"
    "tasks.max"                        = "1"
    "topics"                           = "orders"
    "newrelic.api.url"                 = "https://log-api.newrelic.com/log/v1"
    "newrelic.api.key"                 = "4f209aa9bf056bceed54d8f482c09aefFFFFNRAL"
    "key.converter"                    = "org.apache.kafka.connect.storage.StringConverter"
    "value.converter"                  = "org.apache.kafka.connect.json.JsonConverter"
    "value.converter.schemas.enable"   = "false"
    "transforms"                       = "addField"
    "transforms.addField.type"         = "com.example.newrelic.AddFieldSMT"
    "errors.tolerance"                 = "none"
    "errors.log.enable"                = "true"
    "errors.log.include.messages"      = "true"
  }

  kafka_cluster {
    apache_kafka_cluster {
      bootstrap_servers = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls

      vpc {
        security_groups = [aws_security_group.msk_connect_sg.id]
        subnets         = aws_subnet.msk_private_subnets[*].id  # Deploy across 3 private subnets with NAT Gateway
      }
    }
  }

  kafka_cluster_client_authentication {
    authentication_type = "NONE"
  }

  kafka_cluster_encryption_in_transit {
    encryption_type = "TLS"
  }

  plugin {
    custom_plugin {
      arn      = "arn:aws:kafkaconnect:us-east-1:290384550501:custom-plugin/kafka-sink-connect-nr-plugin/ca262d50-47ed-4dd9-9f42-d10693e2dd71-3"
      revision = 1
    }
  }

  log_delivery {
    worker_log_delivery {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_connect_logs.name
      }
    }
  }

  service_execution_role_arn = aws_iam_role.msk_connect_role.arn

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "NewRelic sink connector for orders topic"
    Name        = "kafka-sink-nr-connector"
  }

  depends_on = [
    aws_msk_cluster.msk_cluster,
    aws_iam_role_policy_attachment.msk_connect_msk_attach,
    aws_iam_role_policy_attachment.msk_connect_logs_attach,
    aws_iam_role_policy_attachment.msk_connect_vpc_attach
  ]
}

# ----------------------------------------------------------------------------
# NAT Gateway for Internet Access (MSK Connect to NewRelic)
# ----------------------------------------------------------------------------

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "NAT Gateway for MSK Connect internet access"
    Name        = "dev-msk-crash-course-nat-eip"
  }

  depends_on = [aws_internet_gateway.msk_igw]
}

# NAT Gateway in public subnet
resource "aws_nat_gateway" "msk_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "NAT Gateway for MSK Connect internet access"
    Name        = "dev-msk-crash-course-nat"
  }

  depends_on = [aws_internet_gateway.msk_igw]
}

# Private Route Table for MSK Connect subnets
resource "aws_route_table" "msk_private_rt" {
  vpc_id = aws_vpc.msk_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.msk_nat.id
  }

  tags = {
    Environment = "dev"
    Project     = "msk-crash-course"
    ManagedBy   = "Terraform"
    Owner       = "Development Team"
    Purpose     = "Private route table with NAT Gateway"
    Name        = "dev-msk-crash-course-private-rt"
  }
}

# Associate public subnet with public route table (Internet Gateway)
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.msk_rt.id
}

# Associate all 3 MSK private subnets with private route table (NAT Gateway)
resource "aws_route_table_association" "msk_private_rta" {
  count          = 3  # All 3 MSK broker subnets use NAT Gateway
  subnet_id      = aws_subnet.msk_private_subnets[count.index].id
  route_table_id = aws_route_table.msk_private_rt.id
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

output "nat_gateway_id" {
  description = "ID of the NAT Gateway for MSK Connect internet access"
  value       = aws_nat_gateway.msk_nat.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

# ----------------------------------------------------------------------------
# MSK Connect Outputs
# ----------------------------------------------------------------------------

output "msk_connect_connector_arn" {
  description = "ARN of the MSK Connect connector"
  value       = aws_mskconnect_connector.newrelic_sink.arn
}

output "msk_connect_connector_version" {
  description = "Version of the MSK Connect connector"
  value       = aws_mskconnect_connector.newrelic_sink.version
}

output "msk_connect_log_group" {
  description = "CloudWatch log group for MSK Connect"
  value       = aws_cloudwatch_log_group.msk_connect_logs.name
}

output "msk_connect_verification_commands" {
  description = "Commands to verify MSK Connect connector"
  value = <<-EOT
    # Check connector status (including state: CREATING, RUNNING, FAILED, etc.)
    aws kafkaconnect describe-connector \
      --connector-arn ${aws_mskconnect_connector.newrelic_sink.arn} \
      --profile msk-dev-user \
      --query 'connectorState' \
      --output text
    
    # View full connector details
    aws kafkaconnect describe-connector \
      --connector-arn ${aws_mskconnect_connector.newrelic_sink.arn} \
      --profile msk-dev-user
    
    # View connector logs (real-time)
    aws logs tail /aws/msk-connect/kafka-sink-nr-connector --follow --profile msk-dev-user
    
    # Produce test message to orders topic (from EC2 client)
    echo '{"order_id": "12345", "customer": "John Doe", "amount": 99.99, "timestamp": "'$(date -Iseconds)'"}' | \
      /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server ${aws_msk_cluster.msk_cluster.bootstrap_brokers_tls} \
      --topic orders
    
    # Check NewRelic for logs
    # Go to: https://one.newrelic.com/launcher/logger.log-launcher
  EOT
}

