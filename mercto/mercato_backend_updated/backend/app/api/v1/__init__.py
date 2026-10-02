from fastapi import APIRouter

from app.api.v1 import (
    admin_analytics,
    auth,
    cart,
    categories,
    me,
    notifications,
    orders,
    plans,
    product_images,
    products,
    stores,
    team,
    tenants,
    theme,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(me.router)
api_router.include_router(tenants.router)
api_router.include_router(plans.router)
api_router.include_router(theme.router)
api_router.include_router(categories.router)
api_router.include_router(products.router)
api_router.include_router(product_images.router)
api_router.include_router(stores.router)
api_router.include_router(cart.router)
api_router.include_router(orders.router)
api_router.include_router(team.router)
api_router.include_router(notifications.router)
api_router.include_router(admin_analytics.router)
