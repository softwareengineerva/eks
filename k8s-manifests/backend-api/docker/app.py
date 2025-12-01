#!/usr/bin/env python3
"""
Simple Flask API for demonstrating Linkerd mTLS
Connects to PostgreSQL and exposes REST endpoints
"""

import os
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, jsonify, request
from datetime import datetime

app = Flask(__name__)

# Database configuration from environment
DB_HOST = os.getenv('DB_HOST', 'postgres.postgres.svc.cluster.local')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'testdb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')


def get_db_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5
        )
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        raise


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'backend-api',
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/health', methods=['GET'])
def api_health():
    """API health check with database connectivity test"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT version();')
        db_version = cursor.fetchone()[0]
        cursor.close()
        conn.close()

        return jsonify({
            'status': 'healthy',
            'service': 'backend-api',
            'database': 'connected',
            'db_version': db_version,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'service': 'backend-api',
            'database': 'disconnected',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503


@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users from database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT id, name, email, created_at FROM users ORDER BY id;')
        users = cursor.fetchall()
        cursor.close()
        conn.close()

        return jsonify({
            'count': len(users),
            'users': users
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        }), 500


@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get specific user by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT id, name, email, created_at FROM users WHERE id = %s;', (user_id,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if user:
            return jsonify(user)
        else:
            return jsonify({'error': 'User not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json()

        if not data or 'name' not in data or 'email' not in data:
            return jsonify({'error': 'Missing required fields: name, email'}), 400

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute(
            'INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id, name, email, created_at;',
            (data['name'], data['email'])
        )
        new_user = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify(new_user), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get database statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Get user count
        cursor.execute('SELECT COUNT(*) as count FROM users;')
        user_count = cursor.fetchone()['count']

        # Get recent users
        cursor.execute('SELECT COUNT(*) as count FROM users WHERE created_at > NOW() - INTERVAL \'1 hour\';')
        recent_count = cursor.fetchone()['count']

        cursor.close()
        conn.close()

        return jsonify({
            'total_users': user_count,
            'users_last_hour': recent_count,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Initialize database table on startup
    try:
        print("Initializing database...")
        conn = get_db_connection()
        cursor = conn.cursor()

        # Create users table if not exists
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ''')

        # Insert sample data if table is empty
        cursor.execute('SELECT COUNT(*) FROM users;')
        count = cursor.fetchone()[0]

        if count == 0:
            print("Inserting sample data...")
            sample_users = [
                ('Alice Johnson', 'alice@example.com'),
                ('Bob Smith', 'bob@example.com'),
                ('Carol Williams', 'carol@example.com'),
                ('David Brown', 'david@example.com'),
                ('Eve Davis', 'eve@example.com')
            ]

            for name, email in sample_users:
                cursor.execute(
                    'INSERT INTO users (name, email) VALUES (%s, %s);',
                    (name, email)
                )

        conn.commit()
        cursor.close()
        conn.close()
        print("Database initialization complete!")

    except Exception as e:
        print(f"Database initialization error: {e}")

    # Start Flask server
    app.run(host='0.0.0.0', port=8080, debug=False)
