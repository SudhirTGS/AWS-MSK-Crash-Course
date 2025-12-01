# AWS Account and Credentials Configuration for MSK Deployment
# Update these values with your specific AWS account details

# ==============================================================================
# AWS AUTHENTICATION CONFIGURATION
# ==============================================================================

# Option 1: AWS CLI Profile (RECOMMENDED)
aws_profile = "msk-dev-user"  # Your IAM user profile name

# Option 2: AWS Account ID (For validation)
aws_account_id = "290384550501"  # Your sudhir account ID from earlier

# ==============================================================================
# AWS REGION CONFIGURATION
# ==============================================================================

aws_region = "us-east-1"

# ==============================================================================
# DEPLOYMENT TAGS
# ==============================================================================

deployment_tags = {
  Owner           = "Sudhir Kilani"                    
  Email          = "sudhir.kilani1431987@gmail.com"   
  Environment    = "dev"
  Project        = "msk-crash-course"
  CreatedBy      = "terraform"
  CostCenter     = "Development"               
  AutoShutdown   = "true"                         
  Purpose        = "MSK Learning and Testing"
}

# ==============================================================================
# DEPLOYMENT NOTES
# ==============================================================================
# 
# This file is no longer needed since main.tf uses hardcoded values
# 
# AWS CLI Profile Configuration Required:
# 
# 1. Install AWS CLI: https://aws.amazon.com/cli/
# 2. Configure profile: aws configure --profile msk-dev-user
# 3. Test connection: aws sts get-caller-identity --profile msk-dev-user
# 4. Deploy: terraform init && terraform plan && terraform apply
#
# The main.tf file now includes:
# - AWS provider with profile = "msk-dev-user" 
# - Account validation: allowed_account_ids = ["290384550501"]
# - All configuration is hardcoded (no variables needed)
#
# ==============================================================================