from typing import Optional
from uuid import UUID
from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.domain.legal_audit import LegalAuditLog

async def record_legal_audit_event(
    request: Request,
    action_type: str,
    user_id: Optional[UUID],
    db: AsyncSession
) -> None:
    """
    Statutory audit log function fulfilling CERT-In 180-day directions and DPDP Act compliance.
    Extracts transport metadata and persists immutable entry to public.legal_audit_logs.
    """
    client_ip = "127.0.0.1"
    client_port = 0

    if request.client:
        client_ip = request.client.host
        client_port = request.client.port

    user_agent = request.headers.get("User-Agent", "Unknown-Client")
    installation_uuid = request.headers.get("X-Installation-UUID", "UNSPECIFIED")

    audit_entry = LegalAuditLog(
        user_id=user_id,
        action_type=action_type,
        ip_address=client_ip,
        client_port=client_port,
        user_agent=user_agent,
        installation_uuid=installation_uuid
    )
    db.add(audit_entry)
    await db.commit()
