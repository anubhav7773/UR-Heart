import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.orm import Match, ChatMessage, User, UserPhoto
from app.models.schemas import (
    APIResponse,
    MatchRead,
    ChatMessageRead,
    SendMessageRequest,
    UploadMediaData,
    WhatsAppBridgeStatusData,
)
from app.services.storage_engine import StorageEngineService

router = APIRouter(prefix="/chat", tags=["Real-Time Chat & Media Attachments"])


@router.get("/matches", response_model=APIResponse[List[MatchRead]])
@router.get("/conversations", response_model=APIResponse[List[MatchRead]])
async def get_matches(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetches all active matches for the authenticated user with target user profile details.
    Safely excludes blocked users and handles empty matches table with HTTP 200 empty list.
    """
    match_list: List[MatchRead] = []
    try:
        user_uuid = uuid.UUID(current_user_id)

        # Exclude blocked users (both directions)
        blocked_res1 = await db.execute(select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user_uuid))
        blocked_res2 = await db.execute(select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user_uuid))
        blocked_ids = set(blocked_res1.scalars().all()).union(set(blocked_res2.scalars().all()))

        matches_res = await db.execute(
            select(Match).where(
                or_(Match.user1_id == user_uuid, Match.user2_id == user_uuid)
            )
        )
        matches = matches_res.scalars().all()

        for m in matches:
            try:
                target_id = m.user2_id if m.user1_id == user_uuid else m.user1_id
                if target_id in blocked_ids:
                    continue

                target_res = await db.execute(
                    select(User).where(User.id == target_id).options(selectinload(User.photos))
                )
                target_user = target_res.scalars().first()

                target_name = target_user.full_name if target_user else "Matched User"
                target_photo = (
                    target_user.photos[0].photo_url
                    if target_user and target_user.photos
                    else ""
                )

                # Get last message
                last_msg_res = await db.execute(
                    select(ChatMessage)
                    .where(ChatMessage.match_id == m.id)
                    .order_by(ChatMessage.created_at.desc())
                    .limit(1)
                )
                last_msg = last_msg_res.scalars().first()
                last_text = last_msg.content if last_msg else "Matched! Send a message."

                match_list.append(
                    MatchRead(
                        id=str(m.id),
                        target_user_id=str(target_id),
                        target_user_name=target_name,
                        target_user_photo=target_photo,
                        mutual_message_count=m.mutual_message_count,
                        is_whatsapp_unlocked=m.is_whatsapp_unlocked,
                        last_message=last_text,
                        updated_at=m.created_at.isoformat() if m.created_at else "",
                    )
                )
            except Exception:
                pass
    except Exception:
        await db.rollback()
        match_list = []

    return APIResponse(success=True, data=match_list)


@router.get("/messages/{match_id}", response_model=APIResponse[List[ChatMessageRead]])
async def get_chat_messages(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrieves message history for a specified match ID.
    """
    try:
        match_uuid = uuid.UUID(match_id)
        msgs_res = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.match_id == match_uuid)
            .order_by(ChatMessage.created_at.asc())
        )
        messages = msgs_res.scalars().all()
    except Exception:
        messages = []

    result = [
        ChatMessageRead(
            id=str(msg.id),
            match_id=str(msg.match_id),
            sender_id=str(msg.sender_id),
            content=msg.content,
            media_url=msg.media_url,
            media_type=msg.media_type or "text",
            created_at=msg.created_at.isoformat() if msg.created_at else "",
        )
        for msg in messages
    ]
    return APIResponse(success=True, data=result)


@router.post("/send", response_model=APIResponse[ChatMessageRead])
async def send_chat_message(
    payload: SendMessageRequest,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Sends a new text or media message within an active match.
    """
    match_uuid = uuid.UUID(payload.match_id)
    sender_uuid = uuid.UUID(current_user_id)

    new_msg = ChatMessage(
        match_id=match_uuid,
        sender_id=sender_uuid,
        content=payload.content,
        media_url=payload.media_url,
        media_type=payload.media_type or "text",
    )
    db.add(new_msg)

    # Increment message count on match for WhatsApp bridge unlocking
    match_res = await db.execute(select(Match).where(Match.id == match_uuid))
    match_obj = match_res.scalars().first()
    if match_obj:
        match_obj.mutual_message_count += 1
        if match_obj.mutual_message_count >= 15:
            match_obj.is_whatsapp_unlocked = True

    await db.commit()
    await db.refresh(new_msg)

    return APIResponse(
        success=True,
        data=ChatMessageRead(
            id=str(new_msg.id),
            match_id=str(new_msg.match_id),
            sender_id=str(new_msg.sender_id),
            content=new_msg.content,
            media_url=new_msg.media_url,
            media_type=new_msg.media_type,
            created_at=new_msg.created_at.isoformat() if new_msg.created_at else "",
        )
    )


@router.post("/upload-media", response_model=APIResponse[UploadMediaData])
async def upload_chat_media(
    file: UploadFile = File(...),
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Uploads chat media attachment (image/audio) to Supabase Storage bucket ('chat-media').
    """
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Filename is missing."
        )

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    cdn_url = await StorageEngineService.upload_chat_media(
        file_bytes=file_bytes,
        filename=file.filename
    )

    return APIResponse(
        success=True,
        message="Media uploaded to chat-media storage successfully.",
        data=UploadMediaData(media_url=cdn_url, is_view_once=False)
    )


@router.get("/whatsapp-bridge-status/{match_id}", response_model=APIResponse[WhatsAppBridgeStatusData])
async def get_whatsapp_bridge_status(
    match_id: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Checks Safe WhatsApp Bridge status (15 mutual messages threshold).
    Unlocks and retrieves verified phone number from DB when 15 mutual messages are exchanged.
    """
    count = 0
    unlocked = False
    target_phone = None

    try:
        user_uuid = uuid.UUID(current_user_id)
        match_uuid = uuid.UUID(match_id)
        match_res = await db.execute(select(Match).where(Match.id == match_uuid))
        match_obj = match_res.scalars().first()

        if match_obj:
            count = match_obj.mutual_message_count
            unlocked = match_obj.is_whatsapp_unlocked or (count >= 15)

            target_id = match_obj.user2_id if match_obj.user1_id == user_uuid else match_obj.user1_id
            target_res = await db.execute(select(User).where(User.id == target_id))
            target_user = target_res.scalars().first()
            if target_user and target_user.phone_number:
                target_phone = target_user.phone_number
    except Exception:
        await db.rollback()

    return APIResponse(
        success=True,
        data=WhatsAppBridgeStatusData(
            match_id=match_id,
            mutual_message_count=count,
            required_threshold=15,
            is_whatsapp_unlocked=unlocked,
            phone_number=target_phone if unlocked and target_phone else None,
        )
    )
