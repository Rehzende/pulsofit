from typing import Literal
from pydantic import BaseModel


class DeviceTokenRegister(BaseModel):
    token: str
    platform: Literal["android", "ios"]


class DeviceTokenDelete(BaseModel):
    token: str
