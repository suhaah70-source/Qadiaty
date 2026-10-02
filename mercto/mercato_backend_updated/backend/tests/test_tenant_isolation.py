def authenticate(client, phone, name):
    client.post("/api/v1/auth/request-otp", json={"phone": phone})
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
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def apply_for_store(client, headers, name):
    response = client.post(
        "/api/v1/stores/applications",
        headers=headers,
        json={"name": name, "city": "طرابلس", "store_category": "clothing"},
    )
    assert response.status_code == 201, response.text
    assert name.split()[0] in response.json()["slug"]
    return response.json()


def test_vendor_cannot_read_another_store_products(client):
    admin_headers = authenticate(client, "0915750694", "مديرة المنصة")
    owner_a = authenticate(client, "0912345678", "صاحب المتجر الأول")
    owner_b = authenticate(client, "0912345679", "صاحب المتجر الثاني")
    store_a = apply_for_store(client, owner_a, "متجر الملابس الأول")
    store_b = apply_for_store(client, owner_b, "متجر الملابس الثاني")

    for store in (store_a, store_b):
        approval = client.patch(
            f"/api/v1/tenants/{store['id']}/status",
            headers=admin_headers,
            json={"status": "ACTIVE"},
        )
        assert approval.status_code == 200, approval.text

    created = client.post(
        f"/api/v1/tenants/{store_b['id']}/products",
        headers=owner_b,
        json={"name": "منتج خاص", "sku": "B-1", "price": "10.00", "stock": 3},
    )
    assert created.status_code == 201, created.text

    forbidden = client.get(
        f"/api/v1/tenants/{store_b['id']}/products", headers=owner_a
    )
    assert forbidden.status_code == 404
