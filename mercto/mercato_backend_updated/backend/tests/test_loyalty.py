from decimal import Decimal

from backend.app.database import get_db
from backend.app.models import Order, Store, User
from app.main import app


def register_customer(client):
    client.post("/api/v1/auth/request-otp", json={"phone": "0915550011"})
    response = client.post(
        "/api/v1/auth/verify-otp",
        json={
            "phone": "0915550011",
            "code": "123456",
            "full_name": "Customer",
            "city": "Tripoli",
            "password": "Password123!",
            "terms_accepted": True,
        },
    )
    assert response.status_code == 200, response.text
    auth = response.json()
    return auth, {"Authorization": f"Bearer {auth['access_token']}"}


def test_points_are_awarded_once_on_delivery_and_rewards_redeem_exactly(client):
    auth, headers = register_customer(client)
    db = next(app.dependency_overrides[get_db]())
    customer = db.get(User, auth["user"]["id"])
    store = Store(
        owner_id=customer.id,
        code="LOYALTY-1",
        slug="loyalty-shop",
        name="Shop",
        city="Tripoli",
        status="APPROVED",
    )
    db.add(store)
    db.flush()
    qualifying = Order(
        user_id=customer.id,
        store_id=store.id,
        delivery_address_snapshot="Tripoli",
        subtotal=Decimal("20.00"),
        delivery_fee=Decimal("0.00"),
        total=Decimal("20.00"),
        status="READY",
    )
    below = Order(
        user_id=customer.id,
        store_id=store.id,
        delivery_address_snapshot="Tripoli",
        subtotal=Decimal("19.99"),
        delivery_fee=Decimal("0.00"),
        total=Decimal("19.99"),
        status="READY",
    )
    db.add_all([qualifying, below])
    db.commit()
    qualifying_id, below_id = qualifying.id, below.id
    db.close()

    url = "/api/v1/vendor/orders/{}/status"
    completed = client.patch(url.format(qualifying_id), headers=headers, json={"status": "DELIVERED"})
    assert completed.status_code == 200, completed.text
    profile = client.get("/api/v1/auth/me", headers=headers).json()
    assert profile["loyalty_points"] == 0.5
    assert profile["wallet_balance"] == 0

    duplicate = client.patch(url.format(qualifying_id), headers=headers, json={"status": "DELIVERED"})
    assert duplicate.status_code == 409
    not_qualified = client.patch(url.format(below_id), headers=headers, json={"status": "DELIVERED"})
    assert not_qualified.status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers).json()["loyalty_points"] == 0.5

    db = next(app.dependency_overrides[get_db]())
    customer = db.get(User, auth["user"]["id"])
    customer.loyalty_half_points = 240  # 120 points
    db.commit()
    db.close()
    reward = client.post("/api/v1/loyalty/redeem", headers=headers)
    assert reward.status_code == 200, reward.text
    assert reward.json()["loyalty_points"] == 20
    assert reward.json()["wallet_balance"] == 5
    assert client.post("/api/v1/loyalty/redeem", headers=headers).status_code == 409
