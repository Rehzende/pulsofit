import pytest

@pytest.mark.asyncio
async def test_simple(client):
    """Simple test to debug fixture setup."""
    print("Client created:", type(client))
    response = await client.get("/api/v1/")
    print("Response status:", response.status_code if hasattr(response, 'status_code') else 'N/A')
    assert response.status_code in [200, 404]  # Just check it responds
