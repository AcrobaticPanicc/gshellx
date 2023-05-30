import requests
from . import config
from rich.markdown import Markdown


def raise_exception_if_no_key():
    if config.OPENAI_KEY is None:
        raise ValueError(Markdown("You need to set your OPENAI_KEY to use this script. \
        You can set it temporarily by running this on your terminal: `export OPENAI_KEY=YOUR_KEY_HERE`"))


def make_request_to_openai_api(data):
    response = requests.post('https://api.openai.com/v1/chat/completions', headers=config.HEADERS, json=data)
    if response.status_code != 200:
        raise ValueError("Your request to OpenAI API failed: ", response.json()['error'])
    return response.json()['choices'][0]['message']['content'].strip()


def request_to_completions(prompt, model="gpt-3.5-turbo", max_tokens=500, temperature=0):
    data = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a shell command expert..."},
            {"role": "user", "content": prompt}
        ],
        "max_tokens": max_tokens,
        "temperature": temperature
    }
    return make_request_to_openai_api(data)
