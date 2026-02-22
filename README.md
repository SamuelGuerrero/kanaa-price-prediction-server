# Kanaa Price Prediction Server

Simple Flask API that loads a pre-trained model (`best_xgb_model.pkl`) and exposes a `/predict` endpoint.

## Endpoints
- `POST /predict` — expects JSON with a `features` object
- `GET /health` — health check

### Example request
```bash
curl -X POST http://localhost:6666/predict \
  -H "Content-Type: application/json" \
  -d '{"features":{"feature1":123,"feature2":456}}'
```

## Local run
```bash
python main.py
```

## Render deployment (manual)
1. Push this repo to GitHub/GitLab.
2. In Render, click **New +** → **Web Service**.
3. Connect the repo and choose the branch.
4. Render will detect `render.yaml` and prefill settings.
5. Click **Create Web Service**.

## Notes
- Render will inject `PORT`; the app uses it automatically.
- Ensure `best_xgb_model.pkl` is in the repo root and committed.

## AWS Lambda Deploy (Container + Function URL)
This repo includes:
- `Dockerfile.lambda`
- `.dockerignore`
- `scripts/deploy_lambda.sh`

### Prerequisites
- AWS CLI configured (`aws configure`)
- Docker installed and running
- IAM permission to manage ECR, Lambda, IAM role, and CloudWatch logs

### Deploy commands
```bash
export AWS_REGION=us-east-1
export APP_NAME=kanaa-price-prediction

./scripts/deploy_lambda.sh deploy
```

The script will:
1. Create (or reuse) an IAM role for Lambda.
2. Build and push the container image to ECR.
3. Create (or update) the Lambda function.
4. Configure Function URL with public access.
5. Set basic cost controls (reserved concurrency and short log retention).

### Update after code changes
```bash
./scripts/deploy_lambda.sh deploy
```
