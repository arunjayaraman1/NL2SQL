import requests
import os

API_KEY = ""

url = "https://openrouter.ai/api/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

payload = {
    "model": "openai/gpt-3.5-turbo",
    "messages": [
        {"role": "user", "content": "Say hello"}
    ]
}

response = requests.post(url, headers=headers, json=payload)

print(response.status_code)
print(response.text)