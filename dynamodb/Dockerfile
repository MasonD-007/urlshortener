FROM debian:bullseye-slim

# Set environment variables
ENV DYNAMODB_PORT=8000
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    openjdk-11-jre-headless \
    wget \
    curl \
    unzip \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Create directory for DynamoDB Local
WORKDIR /dynamodb-local

# Download and extract DynamoDB Local
RUN wget -q https://s3.us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz && \
    tar -xzf dynamodb_local_latest.tar.gz && \
    rm dynamodb_local_latest.tar.gz

# Create data directory for persistence
RUN mkdir -p /dynamodb-local/data

# Expose DynamoDB Local port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/ || exit 1

# Start DynamoDB Local
CMD ["java", "-Djava.library.path=./DynamoDBLocal_lib", "-jar", "DynamoDBLocal.jar", "-sharedDb", "-dbPath", "./data", "-port", "8000"]
