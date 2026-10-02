from __future__ import annotations

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[3]
CUSTOMER_ROOT = PROJECT_ROOT / "mercato_customer_app_flutter"
CUSTOMER_BACKEND = CUSTOMER_ROOT / "backend"
DATABASE_FILE = CUSTOMER_BACKEND / "mercato.db"
load_dotenv(PROJECT_ROOT / ".env")

if not CUSTOMER_BACKEND.is_dir():
    raise RuntimeError(f"Customer backend directory is missing: {CUSTOMER_BACKEND}")

sys.path.insert(0, str(CUSTOMER_ROOT))
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("DATABASE_URL", f"sqlite:///{DATABASE_FILE.as_posix()}")

from backend.app.main import app  # noqa: E402
from app.compat_dashboard import attach_dashboard_compatibility  # noqa: E402

attach_dashboard_compatibility(app)
