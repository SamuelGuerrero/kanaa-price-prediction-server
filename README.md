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
