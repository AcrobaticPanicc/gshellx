import os

OPENAI_KEY = os.environ["OPENAI_KEY"]

HEADERS = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {OPENAI_KEY}',
}
