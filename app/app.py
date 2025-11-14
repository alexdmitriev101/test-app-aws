# app/app.py
from flask import Flask, jsonify
import os
import psycopg2

app = Flask(__name__)

def get_db():
    return psycopg2.connect(os.environ['DATABASE_URL'])

@app.route('/api/health')
def health():
    try:
        conn = get_db()
        conn.close()
        return jsonify({"status": "ok", "db": "connected"})
    except:
        return jsonify({"status": "error", "db": "failed"}), 500

@app.route('/api/data')
def data():
    return jsonify({"message": "Hello from backend!", "env": os.environ.get("ENV", "unknown")})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
