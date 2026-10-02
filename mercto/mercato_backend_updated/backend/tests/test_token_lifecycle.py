def register(client, phone, name):
    requested = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    assert requested.status_code == 200
    response = client.post(
        "/api/v1/auth/verify-otp",
        json={
            "phone": phone,
            "code": "123456",
            "full_name": name,
            "city": "طرابلس",
            "password": "Password123!",
            "terms_accepted": True,
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_phone_auth_accepts_arabic_name_and_refreshes_tokens(client):
    auth = register(client, "0912345678", "محمد العلي")
    assert auth["user"]["full_name"] == "محمد العلي"
    assert auth["user"]["role"] == "CUSTOMER"

    profile = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {auth['access_token']}"},
    )
    assert profile.status_code == 200
    assert profile.json()["full_name"] == "محمد العلي"

    refreshed = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": auth["refresh_token"]}
    )
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"]
    assert refreshed.json()["refresh_token"]

    login = client.post(
        "/api/v1/auth/login",
        json={"phone": "0912345678", "password": "Password123!"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["full_name"] == "محمد العلي"


def test_configured_admin_phone_gets_admin_role_and_can_log_in(client):
    auth = register(client, "0915750694", "مديرة المنصة")
    assert auth["user"]["role"] == "ADMIN"
    login = client.post(
        "/api/v1/auth/login",
        json={"phone": "+218915750694", "password": "Password123!"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["role"] == "ADMIN"
