import json
import urllib.error
import urllib.request

from django.conf import settings

from .models import DeviceToken, Notification, User


def _send_fcm_message(token: str, title: str, body: str) -> bool:
    server_key = (getattr(settings, "FCM_SERVER_KEY", "") or "").strip()
    if not server_key:
        return False

    payload = {
        "to": token,
        "notification": {"title": title, "body": body},
        "data": {"title": title, "message": body},
        "priority": "high",
    }
    req = urllib.request.Request(
        "https://fcm.googleapis.com/fcm/send",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"key={server_key}",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            raw = response.read().decode("utf-8")
        parsed = json.loads(raw) if raw else {}
        if isinstance(parsed, dict):
            if parsed.get("failure", 0) > 0:
                return False
        return True
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return False


def create_notification(
    *,
    user: User,
    message: str,
    title: str = "ServiceApp",
) -> Notification:
    notification = Notification.objects.create(user=user, message=message)
    active_tokens = DeviceToken.objects.filter(user=user, is_active=True).values_list(
        "token",
        flat=True,
    )
    for token in active_tokens:
        delivered = _send_fcm_message(token=token, title=title, body=message)
        if not delivered:
            DeviceToken.objects.filter(token=token).update(is_active=False)
    return notification
