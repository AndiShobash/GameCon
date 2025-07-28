#!/bin/sh
echo "Waiting for database to be ready..."

# Use environment variables with defaults 
DB_HOST=${POSTGRES_HOST:-postgres_db}
DB_PORT=${POSTGRES_PORT:-5432}

# Wait for Postgres to accept connections
while ! nc -z $DB_HOST $DB_PORT; do
    echo "Waiting for Postgres on $DB_HOST:$DB_PORT..."
    sleep 1
done
echo "Database is up!"

cd app || exit
export FLASK_APP=app.py

echo "Starting Flask app..."
exec python app.py