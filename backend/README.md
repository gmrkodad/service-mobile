# Service Mobile Backend

This backend is a Django REST API scaffold that matches the Flutter client in this repo.

## Stack

- Django
- Django REST Framework
- Simple JWT
- SQLite by default

## Quick Start

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py makemigrations
python manage.py migrate
python manage.py bootstrap_demo \
  --admin-username admin \
  --admin-password admin12345 \
  --admin-email admin@example.com
python manage.py runserver 0.0.0.0:8000
```

For the Android emulator, the Flutter app already points to `http://10.0.2.2:8000`.

## Demo Login

After `bootstrap_demo`, a default admin is available:

- Username: `admin`
- Password: `admin12345`

You can change those values with command flags.

