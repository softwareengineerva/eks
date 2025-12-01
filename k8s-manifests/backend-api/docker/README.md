# Backend API Docker Image

Simple Python Flask API that connects to PostgreSQL to demonstrate Linkerd mTLS.

## Build and Push Image

```bash
# Navigate to docker directory
cd k8s-manifests/backend-api/docker

# Build the image
docker build -t softwareengineerva/backend-api:latest .

# Test locally (optional)
docker run -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  softwareengineerva/backend-api:latest

# Push to Docker Hub
docker push softwareengineerva/backend-api:latest
```

## Alternative: Use ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Create ECR repository
aws ecr create-repository \
  --repository-name backend-api \
  --region us-east-1

# Tag and push
docker tag softwareengineerva/backend-api:latest \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest

docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest
```

## API Endpoints

- `GET /health` - Health check
- `GET /api/health` - API health with database check
- `GET /api/users` - List all users
- `GET /api/users/<id>` - Get specific user
- `POST /api/users` - Create new user (JSON: {name, email})
- `GET /api/stats` - Database statistics

## Environment Variables

- `DB_HOST` - PostgreSQL host (default: postgres.postgres.svc.cluster.local)
- `DB_PORT` - PostgreSQL port (default: 5432)
- `DB_NAME` - Database name (default: testdb)
- `DB_USER` - Database user (default: postgres)
- `DB_PASSWORD` - Database password (default: postgres)
