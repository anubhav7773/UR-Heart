import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.pool import NullPool
from app.core.config import get_settings

settings = get_settings()


@pytest.mark.asyncio
async def test_supabase_cascade_triggers_and_foreign_keys():
    """Verify that cascade cleanup triggers are active and foreign keys have ON DELETE CASCADE."""
    test_engine = create_async_engine(
        settings.SUPABASE_PGBOUNCER_URL,
        poolclass=NullPool,
        connect_args={
            "statement_cache_size": 0,
            "prepared_statement_cache_size": 0,
        }
    )

    async with AsyncSession(test_engine) as session:
        # 1. Verify triggers exist
        trigger_query = text("""
            SELECT trigger_name, event_manipulation, event_object_schema, event_object_table, action_timing 
            FROM information_schema.triggers 
            WHERE trigger_name IN ('trg_user_cascade_cleanup', 'trg_auth_user_deleted');
        """)
        res = await session.execute(trigger_query)
        triggers = {row[0]: dict(row._mapping) for row in res.fetchall()}

        assert "trg_user_cascade_cleanup" in triggers, "Missing trg_user_cascade_cleanup on public.users"
        assert triggers["trg_user_cascade_cleanup"]["event_object_table"] == "users"
        assert triggers["trg_user_cascade_cleanup"]["event_object_schema"] == "public"
        assert triggers["trg_user_cascade_cleanup"]["action_timing"] == "BEFORE"
        assert triggers["trg_user_cascade_cleanup"]["event_manipulation"] == "DELETE"

        assert "trg_auth_user_deleted" in triggers, "Missing trg_auth_user_deleted on auth.users"
        assert triggers["trg_auth_user_deleted"]["event_object_table"] == "users"
        assert triggers["trg_auth_user_deleted"]["event_object_schema"] == "auth"
        assert triggers["trg_auth_user_deleted"]["action_timing"] == "AFTER"
        assert triggers["trg_auth_user_deleted"]["event_manipulation"] == "DELETE"

        # 2. Verify foreign key cascades
        fk_query = text("""
            SELECT 
                tc.table_name, 
                kcu.column_name, 
                rc.delete_rule
            FROM 
                information_schema.table_constraints AS tc 
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name
                  AND ccu.table_schema = tc.table_schema
                JOIN information_schema.referential_constraints AS rc
                  ON rc.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY' 
              AND ccu.table_schema = 'public' 
              AND ccu.table_name = 'users';
        """)
        res = await session.execute(fk_query)
        rows = res.fetchall()
        assert len(rows) > 0, "Expected foreign keys referencing public.users"
        for row in rows:
            table_name, col_name, delete_rule = row[0], row[1], row[2]
            assert delete_rule == "CASCADE", f"Table {table_name}.{col_name} does not have ON DELETE CASCADE (found: {delete_rule})"

    await test_engine.dispose()
