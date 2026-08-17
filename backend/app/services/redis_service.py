import json
import logging
from typing import Optional
from redis import asyncio as aioredis
from app.core.config import settings

logger = logging.getLogger(__name__)


class RedisService:
    _instance: Optional["RedisService"] = None
    _client: Optional[aioredis.Redis] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    async def connect(self):
        """Initialize Redis connection"""
        if not settings.REDIS_URL:
            logger.warning("REDIS_URL not configured, chat Pub/Sub will not work")
            return

        try:
            self._client = await aioredis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_keepalive=True,
                health_check_interval=30,
            )
            # Test connection
            await self._client.ping()
            logger.info("✓ Redis connected")
        except Exception as e:
            logger.error(f"✗ Redis connection failed: {e}")
            self._client = None

    async def disconnect(self):
        """Close Redis connection"""
        if self._client:
            await self._client.close()
            self._client = None
            logger.info("Redis disconnected")

    async def publish(self, channel: str, message: dict):
        """Publish message to Redis channel"""
        if not self._client:
            return

        try:
            await self._client.publish(channel, json.dumps(message))
        except Exception as e:
            logger.error(f"Redis publish error on {channel}: {e}")

    async def subscribe(self, channel: str):
        """Subscribe to Redis channel (returns pubsub object)"""
        if not self._client:
            return None

        try:
            pubsub = self._client.pubsub()
            await pubsub.subscribe(channel)
            return pubsub
        except Exception as e:
            logger.error(f"Redis subscribe error on {channel}: {e}")
            return None

    async def get(self, key: str) -> Optional[str]:
        """Get value from Redis"""
        if not self._client:
            return None

        try:
            return await self._client.get(key)
        except Exception as e:
            logger.error(f"Redis get error for {key}: {e}")
            return None

    async def set(self, key: str, value: str, ex: Optional[int] = None):
        """Set value in Redis with optional expiration"""
        if not self._client:
            return

        try:
            await self._client.set(key, value, ex=ex)
        except Exception as e:
            logger.error(f"Redis set error for {key}: {e}")

    async def delete(self, key: str):
        """Delete key from Redis"""
        if not self._client:
            return

        try:
            await self._client.delete(key)
        except Exception as e:
            logger.error(f"Redis delete error for {key}: {e}")

    async def incr(self, key: str) -> int:
        """Increment value in Redis"""
        if not self._client:
            return 0

        try:
            return await self._client.incr(key)
        except Exception as e:
            logger.error(f"Redis incr error for {key}: {e}")
            return 0


redis_service = RedisService()
