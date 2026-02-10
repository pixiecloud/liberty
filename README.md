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
