# On your LOCAL PC (create the repo structure)
mkdir liberty-pipeline
cd liberty-pipeline

# Create buildspec.yaml
cat > buildspec.yaml <<'EOF'
version: 0.2

phases:
  install:
    runtime-versions:
      docker: 20
    commands:
      - echo "Installing dependencies..."
      - curl -o /tmp/awscli.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
      - unzip /tmp/awscli.zip -d /tmp
      - /tmp/aws/install
      
  pre_build:
    commands:
      - echo "Downloading Liberty from IBM..."
      - LIBERTY_VERSION=26.0.0.1
      - wget https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/${LIBERTY_VERSION}/wlp-javaee8-${LIBERTY_VERSION}.zip
      - unzip wlp-javaee8-${LIBERTY_VERSION}.zip
      
      - echo "Downloading Liberty features..."
      - cd wlp
      - ./bin/installUtility download --location=./feature-cache --acceptLicense \
          beanValidation-2.0 \
          cdi-2.0 \
          jaxrs-2.1 \
          jdbc-4.2 \
          jndi-1.0 \
          jpa-2.2 \
          mpMetrics-3.0 \
          mpHealth-3.0
      
      - echo "Packaging feature cache..."
      - tar -czf liberty-feature-cache-${LIBERTY_VERSION}.tar.gz feature-cache/
      - cd ..
      
  build:
    commands:
      - echo "Uploading to S3..."
      - aws s3 cp wlp-javaee8-${LIBERTY_VERSION}.zip s3://opentofu-state-bucket-donot-delete2/liberty/
      - aws s3 cp wlp/liberty-feature-cache-${LIBERTY_VERSION}.tar.gz s3://opentofu-state-bucket-donot-delete2/liberty/
      
      - echo "Building Docker image..."
      - cd docker-build
      - |
        cat > Dockerfile <<'DOCKERFILE'
        FROM registry.access.redhat.com/ubi8/openjdk-11:latest
        USER root
        ARG AWS_ACCESS_KEY_ID
        ARG AWS_SECRET_ACCESS_KEY
        ARG AWS_DEFAULT_REGION=us-east-1
        RUN microdnf install -y unzip tar gzip && \
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
            unzip awscliv2.zip && \
            ./aws/install && \
            rm -rf aws awscliv2.zip && \
            microdnf clean all
        ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
            AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
            AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
        RUN mkdir -p /opt/ibm && \
            aws s3 cp s3://opentofu-state-bucket-donot-delete2/liberty/wlp-javaee8-26.0.0.1.zip /tmp/ && \
            cd /tmp && unzip wlp-javaee8-26.0.0.1.zip && \
            mv wlp /opt/ibm/wlp && rm wlp-javaee8-26.0.0.1.zip
        RUN aws s3 cp s3://opentofu-state-bucket-donot-delete2/liberty/liberty-feature-cache-26.0.0.1.tar.gz /tmp/ && \
            tar -xzf /tmp/liberty-feature-cache-26.0.0.1.tar.gz -C /opt/ibm/wlp/ && \
            rm /tmp/liberty-feature-cache-26.0.0.1.tar.gz
        ENV AWS_ACCESS_KEY_ID= AWS_SECRET_ACCESS_KEY= AWS_DEFAULT_REGION=
        RUN chown -R 1001:0 /opt/ibm/wlp && chmod -R g+rw /opt/ibm/wlp
        USER 1001
        CMD ["/opt/ibm/wlp/bin/server", "run", "defaultServer"]
        DOCKERFILE
      
      - echo "Logging into ECR..."
      - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 126924000548.dkr.ecr.us-east-1.amazonaws.com
      
      - echo "Building Docker image..."
      - docker build --build-arg AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} --build-arg AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -t liberty-with-deps:${LIBERTY_VERSION} .
      
      - echo "Tagging and pushing to ECR..."
      - docker tag liberty-with-deps:${LIBERTY_VERSION} 126924000548.dkr.ecr.us-east-1.amazonaws.com/liberty/liberty-base:${LIBERTY_VERSION}
      - docker tag liberty-with-deps:${LIBERTY_VERSION} 126924000548.dkr.ecr.us-east-1.amazonaws.com/liberty/liberty-base:latest
      - docker push 126924000548.dkr.ecr.us-east-1.amazonaws.com/liberty/liberty-base:${LIBERTY_VERSION}
      - docker push 126924000548.dkr.ecr.us-east-1.amazonaws.com/liberty/liberty-base:latest

  post_build:
    commands:
      - echo "Build completed successfully!"
      - aws s3 ls s3://opentofu-state-bucket-donot-delete2/liberty/
      - aws ecr describe-images --repository-name liberty/liberty-base --region us-east-1

artifacts:
  files:
    - '**/*'
EOF

# Create README
cat > README.md <<'EOF'
# Liberty Base Image Pipeline

Automated pipeline to build WebSphere Liberty base image with pre-cached features.

## What it does:
1. Downloads Liberty from IBM
2. Downloads features from IBM
3. Uploads to S3
4. Builds Docker image
5. Pushes to ECR

## Trigger:
- Push to main branch
- Manual trigger via AWS Console
- Scheduled (monthly on 1st of month)
EOF

# Push to GitHub
git init
git add .
git commit -m "Initial commit - Liberty pipeline"
git remote add origin https://github.com/yourcompany/liberty-pipeline.git
git push -u origin main


## Step 3: Add IAM Permissions to CodeBuild Role
# Get the CodeBuild role name
ROLE_NAME=$(aws iam list-roles --query 'Roles[?contains(RoleName, `codebuild-liberty`)].RoleName' --output text)

# Attach policies
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser