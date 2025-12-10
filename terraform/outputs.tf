# Terraform Outputs

# Subnet Information
output "msk_private_subnet_ids" {
  description = "IDs of the MSK private subnets."
  value       = aws_subnet.msk_private_subnets[*].id
}

output "msk_private_subnet_cidrs" {
  description = "CIDR blocks of the MSK private subnets."
  value       = aws_subnet.msk_private_subnets[*].cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public_subnet.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet."
  value       = aws_subnet.public_subnet.cidr_block
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.msk_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.msk_vpc.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.msk_vpc.arn
}

# Availability Zones
output "availability_zones" {
  description = "Availability zones used by the cluster"
  value       = slice(data.aws_availability_zones.available.names, 0, 3)
}

# MSK Cluster Information
output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.arn
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.cluster_name
}

output "msk_cluster_kafka_version" {
  description = "Kafka version of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.kafka_version
}

output "msk_cluster_number_of_broker_nodes" {
  description = "Number of broker nodes in the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.number_of_broker_nodes
}

# Bootstrap Brokers - Connection Endpoints
output "bootstrap_brokers_plaintext" {
  description = "Plaintext connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_sasl_scram
}

# Zookeeper Information
output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.msk_cluster.zookeeper_connect_string
}

# Security Group Information
output "msk_security_group_id" {
  description = "ID of the MSK security group"
  value       = aws_security_group.msk_sg.id
}

output "msk_security_group_arn" {
  description = "ARN of the MSK security group"
  value       = aws_security_group.msk_sg.arn
}

# No NAT Gateways in basic setup

# Configuration Information
output "msk_configuration_arn" {
  description = "ARN of the MSK configuration"
  value       = aws_msk_configuration.msk_config.arn
}

output "msk_configuration_latest_revision" {
  description = "Latest revision of the MSK configuration"
  value       = aws_msk_configuration.msk_config.latest_revision
}

# CloudWatch Logs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.msk_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.msk_logs.arn
}

# Connection Information for CLI Access
output "connection_info" {
  description = "Connection information for accessing MSK cluster"
  value = {
    cluster_name        = aws_msk_cluster.msk_cluster.cluster_name
    cluster_arn         = aws_msk_cluster.msk_cluster.arn
    bootstrap_servers   = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
    zookeeper_hosts     = aws_msk_cluster.msk_cluster.zookeeper_connect_string
    vpc_id              = aws_vpc.msk_vpc.id
    security_group_id   = aws_security_group.msk_sg.id
    subnets             = aws_subnet.msk_private_subnets[*].id
  }
}

# Environment and Configuration Summary
output "deployment_summary" {
  description = "Summary of the deployed MSK cluster configuration"
  value = {
    environment           = "dev"
    project_name         = "msk-crash-course"
    cluster_name         = "dev-msk-crash-course-cluster"
    kafka_version        = "3.6.0"
    instance_type        = "kafka.t3.small"
    broker_count         = 3
    storage_size_gb      = 100
    nat_gateways_enabled = true
    iam_auth_enabled     = true
    encryption_enabled   = true
    monitoring_level     = "PER_BROKER"
    region               = "us-east-1"
  }
}