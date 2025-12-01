# AWS MSK Kafka Operations Guide

## Complete Step-by-Step Guide for Producing and Consuming Messages

This guide provides detailed instructions for working with your AWS MSK cluster using the EC2 client instance created by Terraform.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Step 1: Connect to EC2 Instance](#step-1-connect-to-ec2-instance)
3. [Step 2: Verify Kafka Installation](#step-2-verify-kafka-installation)
4. [Step 3: Create a Kafka Topic](#step-3-create-a-kafka-topic)
5. [Step 4: Produce Messages](#step-4-produce-messages)
6. [Step 5: Consume Messages](#step-5-consume-messages)
7. [Advanced Operations](#advanced-operations)
8. [Troubleshooting](#troubleshooting)
9. [Production Application Examples](#production-application-examples)

---

## Prerequisites

### Required Files
- **SSH Key**: `msk-dev-keypair.pem` (located in terraform directory)
- **Terraform Output**: Run `terraform output` to get EC2 public IP

### Cluster Information
- **Cluster Name**: `dev-msk-crash-course-cluster`
- **Kafka Version**: 3.6.0
- **Number of Brokers**: 3 (across 3 availability zones)
- **Instance Type (EC2 Client)**: t3.small (2GB RAM)

---

## Step 1: Connect to EC2 Instance

### Windows PowerShell

```powershell
# Navigate to terraform directory
cd "D:\Backup\Backup-L490\OriginalData\Softwares\VSC-workspace\GH-Copilot-Learning\repo\AWS-MSK-Crash-Course\terraform"

# Fix permissions on .pem file (if needed)
icacls.exe "msk-dev-keypair.pem" /reset
icacls.exe "msk-dev-keypair.pem" /grant:r "$($env:USERNAME):(R)"
icacls.exe "msk-dev-keypair.pem" /inheritance:r

# Connect via SSH
ssh -i "msk-dev-keypair.pem" ec2-user@<EC2_PUBLIC_IP>
```

### Linux/WSL/Mac

```bash
# Navigate to terraform directory
cd /path/to/terraform

# Fix permissions on .pem file
chmod 400 msk-dev-keypair.pem

# Connect via SSH
ssh -i "msk-dev-keypair.pem" ec2-user@<EC2_PUBLIC_IP>
```

### Expected Output
```
The authenticity of host 'XX.XXX.XXX.XXX' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

[ec2-user@ip-10-0-1-xxx ~]$
```

---

## Step 2: Verify Kafka Installation

Once connected to the EC2 instance, verify that Kafka tools are installed and environment variables are set:

```bash
# Check Kafka installation
ls /opt/kafka/bin/

# Verify bootstrap servers environment variable
echo $BOOTSTRAP_SERVERS

# Expected output (plaintext brokers on port 9092):
# b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,
# b-2.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,
# b-3.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092

# Check Kafka heap memory settings
echo $KAFKA_HEAP_OPTS
# Expected output: -Xmx512M -Xms256M

# Verify PATH includes Kafka binaries
which kafka-topics.sh
# Expected output: /opt/kafka/bin/kafka-topics.sh
```

---

## Step 3: Create a Kafka Topic

### Basic Topic Creation

```bash
# Create a topic with 3 partitions and replication factor of 3
kafka-topics.sh --create \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --replication-factor 3 \
  --partitions 3 \
  --topic orders

# Expected output:
# Created topic orders.
```

### List All Topics

```bash
# List all topics in the cluster
kafka-topics.sh --list \
  --bootstrap-server $BOOTSTRAP_SERVERS

# Expected output:
# orders
```

### Describe a Topic

```bash
# Get detailed information about a topic
kafka-topics.sh --describe \
  --topic orders \
  --bootstrap-server $BOOTSTRAP_SERVERS

# Expected output:
# Topic: orders   TopicId: xxxxx   PartitionCount: 3   ReplicationFactor: 3
# Topic: orders   Partition: 0    Leader: 1   Replicas: 1,2,3 Isr: 1,2,3
# Topic: orders   Partition: 1    Leader: 2   Replicas: 2,3,1 Isr: 2,3,1
# Topic: orders   Partition: 2    Leader: 3   Replicas: 3,1,2 Isr: 3,1,2
```

### Create Topic with Specific Configuration

```bash
# Create topic with custom retention and segment size
kafka-topics.sh --create \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --replication-factor 3 \
  --partitions 6 \
  --topic user-events \
  --config retention.ms=86400000 \
  --config segment.bytes=104857600

# retention.ms=86400000 (24 hours retention)
# segment.bytes=104857600 (100MB segment size)
```

---

## Step 4: Produce Messages

### Using Console Producer

```bash
# Start the console producer
kafka-console-producer.sh \
  --broker-list $BOOTSTRAP_SERVERS \
  --topic orders

# The terminal will wait for input. Type messages and press Enter:
```

**Example Messages:**
```
> {"order_id": 1001, "customer": "John Doe", "amount": 250.50, "status": "pending"}
> {"order_id": 1002, "customer": "Jane Smith", "amount": 175.00, "status": "confirmed"}
> {"order_id": 1003, "customer": "Bob Johnson", "amount": 320.75, "status": "pending"}
```

**Press `Ctrl+C` to exit the producer.**

### Produce Messages with Key

```bash
# Produce messages with keys (for partition control)
kafka-console-producer.sh \
  --broker-list $BOOTSTRAP_SERVERS \
  --topic orders \
  --property "parse.key=true" \
  --property "key.separator=:"

# Format: key:value
```

**Example with Keys:**
```
> customer-123:{"order_id": 1004, "customer": "Alice Brown", "amount": 450.00}
> customer-456:{"order_id": 1005, "customer": "Charlie Davis", "amount": 125.50}
```

---

## Step 5: Consume Messages

### Basic Consumer (From Beginning)

Open a **new SSH terminal** to run the consumer while keeping the producer running:

```bash
# Connect to EC2 in a new terminal
ssh -i "msk-dev-keypair.pem" ec2-user@<EC2_PUBLIC_IP>

# Start consumer from the beginning of the topic
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic orders \
  --from-beginning

# Expected output (you'll see all messages):
# {"order_id": 1001, "customer": "John Doe", "amount": 250.50, "status": "pending"}
# {"order_id": 1002, "customer": "Jane Smith", "amount": 175.00, "status": "confirmed"}
# {"order_id": 1003, "customer": "Bob Johnson", "amount": 320.75, "status": "pending"}
```

### Consumer with Key and Value

```bash
# Display both keys and values
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic orders \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" : "

# Expected output:
# customer-123 : {"order_id": 1004, "customer": "Alice Brown", "amount": 450.00}
# customer-456 : {"order_id": 1005, "customer": "Charlie Davis", "amount": 125.50}
```

### Consumer with Consumer Group

```bash
# Create a consumer as part of a consumer group
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic orders \
  --group order-processing-group

# This consumer will only receive new messages (not from beginning)
# Multiple consumers in the same group will share the load
```

### Consumer with Metadata

```bash
# Display partition, offset, timestamp, and message
kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic orders \
  --from-beginning \
  --property print.timestamp=true \
  --property print.partition=true \
  --property print.offset=true

# Expected output:
# CreateTime:1234567890 Partition:0 Offset:0 {"order_id": 1001, ...}
```

---

## Advanced Operations

### Check Consumer Group Status

```bash
# List all consumer groups
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --list

# Describe a specific consumer group
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --group order-processing-group \
  --describe

# Expected output shows lag, current offset, log end offset
```

### Reset Consumer Group Offset

```bash
# Reset to earliest offset (reprocess all messages)
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --group order-processing-group \
  --topic orders \
  --reset-offsets \
  --to-earliest \
  --execute

# Reset to latest offset (skip to newest messages)
kafka-consumer-groups.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --group order-processing-group \
  --topic orders \
  --reset-offsets \
  --to-latest \
  --execute
```

### Delete a Topic

```bash
# Delete a topic (use with caution!)
kafka-topics.sh --delete \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic user-events

# Expected output:
# Topic user-events is marked for deletion.
```

### Alter Topic Configuration

```bash
# Change retention period for a topic
kafka-configs.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --entity-type topics \
  --entity-name orders \
  --alter \
  --add-config retention.ms=172800000

# retention.ms=172800000 (48 hours)
```

---

## Troubleshooting

### Out of Memory Errors

If you encounter Java heap space errors:

```bash
# Set memory limits before running Kafka commands
export KAFKA_HEAP_OPTS="-Xmx512M -Xms256M"

# Verify the setting
echo $KAFKA_HEAP_OPTS

# Now retry your Kafka command
```

### Cannot Connect to Brokers

```bash
# Test connectivity to brokers
telnet b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com 9092

# If connection fails, check:
# 1. Security groups allow traffic on port 9092
# 2. EC2 instance is in the same VPC as MSK cluster
# 3. Bootstrap servers environment variable is set correctly
```

### Verify Bootstrap Servers

```bash
# If BOOTSTRAP_SERVERS is not set, manually set it:
export BOOTSTRAP_SERVERS="b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,b-2.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,b-3.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092"

# Make it persistent by adding to .bashrc
echo 'export BOOTSTRAP_SERVERS="b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,b-2.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092,b-3.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092"' >> ~/.bashrc
source ~/.bashrc
```

---

## Production Application Examples

### Python Consumer Application

Create a file `kafka_consumer.py`:

```python
# Install library: pip install kafka-python

from kafka import KafkaConsumer
import json

# Create consumer
consumer = KafkaConsumer(
    'orders',
    bootstrap_servers=['b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092',
                      'b-2.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092',
                      'b-3.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092'],
    group_id='python-order-processor',
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    auto_offset_reset='earliest',
    enable_auto_commit=True
)

print("Consumer started. Waiting for messages...")

for message in consumer:
    order = message.value
    print(f"Processing order {order['order_id']} for {order['customer']}")
    print(f"  Amount: ${order['amount']}")
    print(f"  Status: {order['status']}")
    print("-" * 50)
```

### Python Producer Application

Create a file `kafka_producer.py`:

```python
# Install library: pip install kafka-python

from kafka import KafkaProducer
import json
import time

# Create producer
producer = KafkaProducer(
    bootstrap_servers=['b-1.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092',
                      'b-2.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092',
                      'b-3.devmskcrashcourseclus.r2qv5o.c21.kafka.us-east-1.amazonaws.com:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Send messages
orders = [
    {"order_id": 2001, "customer": "Emma Wilson", "amount": 599.99, "status": "pending"},
    {"order_id": 2002, "customer": "Michael Brown", "amount": 249.50, "status": "confirmed"},
    {"order_id": 2003, "customer": "Sarah Johnson", "amount": 399.00, "status": "pending"}
]

for order in orders:
    future = producer.send('orders', order)
    result = future.get(timeout=10)
    print(f"Sent order {order['order_id']} to partition {result.partition} at offset {result.offset}")
    time.sleep(1)

producer.flush()
producer.close()
print("All messages sent successfully!")
```

### Running Python Applications on EC2

```bash
# Install Python pip (if not already installed)
sudo yum install -y python3-pip

# Install kafka-python library
pip3 install kafka-python

# Upload your Python scripts
# Option 1: Use SCP from your local machine
scp -i "msk-dev-keypair.pem" kafka_consumer.py ec2-user@<EC2_PUBLIC_IP>:~/
scp -i "msk-dev-keypair.pem" kafka_producer.py ec2-user@<EC2_PUBLIC_IP>:~/

# Option 2: Create files directly on EC2
nano kafka_consumer.py  # Paste the code and save

# Run the producer
python3 kafka_producer.py

# Run the consumer (in a separate terminal)
python3 kafka_consumer.py
```

---

## Best Practices

### 1. Topic Design
- Use meaningful topic names (e.g., `user-events`, `order-processing`)
- Set appropriate partition count based on throughput needs
- Always use replication factor ≥ 2 for production

### 2. Consumer Groups
- Use consumer groups for load distribution
- Monitor consumer lag regularly
- Handle failures gracefully with retry logic

### 3. Message Format
- Use JSON or Avro for structured data
- Include timestamps and message IDs
- Validate messages before processing

### 4. Performance
- Batch messages when possible
- Use compression (snappy or lz4)
- Monitor broker metrics in CloudWatch

### 5. Security
- Use TLS for production (port 9094)
- Implement IAM authentication (port 9098)
- Restrict security group access to specific IPs

---

## Useful Commands Reference

```bash
# Quick reference for common operations

# Topics
kafka-topics.sh --list --bootstrap-server $BOOTSTRAP_SERVERS
kafka-topics.sh --describe --topic TOPIC_NAME --bootstrap-server $BOOTSTRAP_SERVERS
kafka-topics.sh --create --topic TOPIC_NAME --partitions 3 --replication-factor 3 --bootstrap-server $BOOTSTRAP_SERVERS
kafka-topics.sh --delete --topic TOPIC_NAME --bootstrap-server $BOOTSTRAP_SERVERS

# Producer
kafka-console-producer.sh --broker-list $BOOTSTRAP_SERVERS --topic TOPIC_NAME

# Consumer
kafka-console-consumer.sh --bootstrap-server $BOOTSTRAP_SERVERS --topic TOPIC_NAME --from-beginning
kafka-console-consumer.sh --bootstrap-server $BOOTSTRAP_SERVERS --topic TOPIC_NAME --group GROUP_NAME

# Consumer Groups
kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --list
kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --group GROUP_NAME --describe

# Performance Testing
kafka-producer-perf-test.sh --topic TOPIC_NAME --num-records 1000 --record-size 1024 --throughput 100 --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS
kafka-consumer-perf-test.sh --topic TOPIC_NAME --messages 1000 --bootstrap-server $BOOTSTRAP_SERVERS
```

---

## Additional Resources

- **AWS MSK Documentation**: https://docs.aws.amazon.com/msk/
- **Apache Kafka Documentation**: https://kafka.apache.org/documentation/
- **Kafka Python Client**: https://kafka-python.readthedocs.io/
- **CloudWatch Metrics**: Monitor your cluster in AWS Console → CloudWatch

---

## Summary

You now have a complete working MSK cluster with:
- ✅ 3 Kafka brokers across 3 availability zones
- ✅ EC2 client instance with Kafka tools pre-installed
- ✅ Proper networking (VPC, subnets, security groups)
- ✅ CloudWatch logging enabled
- ✅ Environment configured for easy operation

Happy streaming! 🚀
