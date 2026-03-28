from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    urbit_url: str = "http://localhost:8080"
    urbit_code: str = ""
    urbit_ship: str = ""  # without ~
    worker_secret: str = ""
    mail_domain: str = "ships.to"
    outbound_api_key: str = ""
    outbound_provider: str = "resend"  # resend | mailgun | sendgrid
    host: str = "0.0.0.0"
    port: int = 8443
    rate_limit_per_hour: int = 30
    ip_rate_limit_per_hour: int = 60
    outbound_rate_limit_per_hour: int = 10
    convert_images_to_md: bool = True

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
