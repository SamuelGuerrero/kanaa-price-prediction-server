import os
from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import numpy as np

app = Flask(__name__)
CORS(app)

pipeline = joblib.load('best_xgb_model.pkl')

def smart_round(prediction):
    """
    Aplica redondeo inteligente basado en el rango del valor predicho.
    Los datos muestran patrones de múltiplos según el rango.
    """
    pred = float(prediction)
    
    # Para valores muy pequeños (< 1000): redondear a múltiplos de 25
    if pred < 1000:
        return round(pred / 25) * 25
    
    # Para valores pequeños (1000-2000): redondear a múltiplos de 50
    elif pred < 2000:
        return round(pred / 50) * 50
    
    # Para valores medianos (2000-4000): redondear a múltiplos de 100
    elif pred < 4000:
        return round(pred / 100) * 100
    
    # Para valores altos (4000-7000): redondear a múltiplos de 250
    elif pred < 7000:
        return round(pred / 250) * 250
    
    # Para valores muy altos (>= 7000): redondear a múltiplos de 500
    else:
        return round(pred / 500) * 500

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Receive features as a dict
        data = request.json['features']
        
        # Convert to DataFrame (the pipeline expects this)
        df = pd.DataFrame([data])
        
        # Run prediction
        prediction = pipeline.predict(df)
        
        # Aplicar redondeo inteligente
        rounded_prediction = smart_round(prediction[0])
        
        print(f"Predicción original: {prediction[0]}")
        print(f"Predicción redondeada: {rounded_prediction}")
        
        return jsonify({
            'prediction': [rounded_prediction],
            'raw_prediction': prediction.tolist(),
            'success': True
        })
    except Exception as e:
        return jsonify({
            'error': str(e),
            'success': False
        }), 400

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 6666))
    debug = os.environ.get('FLASK_DEBUG', '0') == '1'
    app.run(host='0.0.0.0', port=port, debug=debug)
