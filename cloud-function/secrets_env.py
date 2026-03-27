"""
Load GCP Secret Manager values into os.environ when variables are not already set.
Call once at the start of the Cloud Function handler before any clients or sync work.
"""
import os
import logging
from typing import List, Tuple

logger = logging.getLogger(__name__)

# (environment variable name, Secret Manager secret id)
_SECRET_ENV_MAP: List[Tuple[str, str]] = [
    ("STRIPE_SECRET_KEY", "stripe-api-key"),
    ("AUTOCARE_API_EMAIL", "autocare-api-email"),
    ("AUTOCARE_API_PASSWORD", "autocare-api-password"),
    ("REPLIT_WEBHOOK_URL", "replit-webhook-url"),
    ("REPLIT_WEBHOOK_SECRET", "replit-webhook-secret"),
    ("REPLIT_CONVERSION_WEBHOOK_1_URL", "replit-conversion-webhook-1-url"),
    ("REPLIT_CONVERSION_WEBHOOK_1_SECRET", "replit-conversion-webhook-1-secret"),
    ("REPLIT_CONVERSION_WEBHOOK_2_URL", "replit-conversion-webhook-2-url"),
    ("REPLIT_CONVERSION_WEBHOOK_2_SECRET", "replit-conversion-webhook-2-secret"),
]


def preload_cloud_function_secrets_from_secret_manager() -> None:
    """
    For each mapped env var that is unset or empty, read the corresponding secret
    from Secret Manager and set os.environ. Skips quietly if project id is missing
    or a secret does not exist (optional integrations).
    """
    project_id = os.getenv("GCP_PROJECT") or os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project_id:
        logger.warning(
            "GOOGLE_CLOUD_PROJECT not set; skipping Secret Manager preload (use env vars only)"
        )
        return

    try:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
    except Exception as e:
        logger.warning("Could not create Secret Manager client: %s", e)
        return

    for env_var, secret_id in _SECRET_ENV_MAP:
        if os.getenv(env_var):
            continue
        try:
            name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
            response = client.access_secret_version(request={"name": name})
            value = response.payload.data.decode("UTF-8").strip()
            if value:
                os.environ[env_var] = value
                logger.info("Loaded %s from Secret Manager into environment", env_var)
        except Exception as e:
            logger.debug("Secret %s (%s) not loaded: %s", secret_id, env_var, e)
