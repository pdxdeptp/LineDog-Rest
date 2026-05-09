import os
from dotenv import load_dotenv

load_dotenv()

DB_PATH: str = os.getenv("DB_PATH", "learning.db")
PLAN_MD_PATH: str = os.getenv("PLAN_MD_PATH", "plan.md")
PORT: int = int(os.getenv("PORT", "8765"))
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL: str = "gemini-2.0-flash"
