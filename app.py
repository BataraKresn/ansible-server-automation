from flask import Flask, request
import subprocess
import hmac
import hashlib

app = Flask(__name__)

SECRET = "wfX94t7d3ha96fq7"

def verify_signature(secret, payload, signature):
    mac = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(mac, signature)

@app.route('/webhook', methods=['POST'])
def webhook():
    payload = request.data
    signature = request.headers.get("X-Gitea-Signature", "")

    if not verify_signature(SECRET, payload, signature):
        return "❌ Invalid Secret", 403

    data = request.get_json()
    ref = data.get("ref", "")
    is_main = ref.endswith("/main")

    if is_main:
        subprocess.Popen([
            "ansible-playbook",
            "-i", "/home/ubuntu/ansible/hosts.ini",
            "/home/ubuntu/ansible/deploy_playbook.yml"
        ])
        return "✅ Deploy triggered (main branch push)", 200
    else:
        return "ℹ️ Skipped: not main branch", 200
