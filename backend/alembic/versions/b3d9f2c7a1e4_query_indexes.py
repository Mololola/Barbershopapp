"""indexes for the app's hot queries and queried foreign keys

Revision ID: b3d9f2c7a1e4
Revises: a7c3e9f1b5d2
Create Date: 2026-10-09 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3d9f2c7a1e4'
down_revision: Union[str, Sequence[str], None] = 'a7c3e9f1b5d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (name, table, definition) — each backs a query the app runs that would
# otherwise read the whole table. Columns already covered by a unique
# constraint (businesses.owner_id, likes.post_id, opening_hours.business_id,
# worker_schedules.worker_id, conversations.participant_a_id, …) and FK
# columns only touched by account-deletion cascades are left out.
INDEXES = [
    # Feed: newest posts first, then each post's media and comment count.
    ("posts_created_at_idx", "posts", "(created_at desc)"),
    ("post_media_post_id_idx", "post_media", "(post_id)"),
    # A post's comments, oldest first (also the feed's per-post count).
    ("comments_post_id_created_at_idx", "comments", "(post_id, created_at)"),
    # A profile's or shop's own posts, newest first.
    ("posts_author_id_created_at_idx", "posts", "(author_id, created_at desc)"),
    # My bookings, and the customer RLS policy on bookings.
    ("bookings_customer_id_start_time_idx", "bookings", "(customer_id, start_time)"),
    # A shop's diary and finance window, and the business RLS policy.
    ("bookings_business_id_start_time_idx", "bookings", "(business_id, start_time)"),
    # Shop page.
    ("reviews_business_id_created_at_idx", "reviews", "(business_id, created_at desc)"),
    ("services_business_id_idx", "services", "(business_id)"),
    ("workers_business_id_idx", "workers", "(business_id)"),
    ("locations_business_id_idx", "locations", "(business_id)"),
    # Admin: a customer's reviews.
    ("reviews_customer_id_idx", "reviews", "(customer_id)"),
    # Inbox: participant_a_id is the leading column of the unique
    # constraint; the OR's other half needs its own index.
    ("conversations_participant_b_id_idx", "conversations", "(participant_b_id)"),
    ("messages_conversation_id_created_at_idx", "messages", "(conversation_id, created_at)"),
    # Rewards balance, history and withdrawals.
    ("reward_ledger_customer_id_created_at_idx", "reward_ledger", "(customer_id, created_at desc)"),
    ("payout_requests_profile_id_requested_at_idx", "payout_requests", "(profile_id, requested_at desc)"),
    # Finance costs, and the Stripe webhook's lookup by subscription.
    ("business_cost_items_business_id_idx", "business_cost_items", "(business_id)"),
    (
        "business_cost_items_stripe_subscription_id_idx",
        "business_cost_items",
        "(stripe_subscription_id) where stripe_subscription_id is not null",
    ),
    # Staff: pending leave requests and a shop's invitations. A worker's
    # own pending invitations are already served by the partial unique
    # index on pending invitations.
    ("worker_leave_requests_business_id_idx", "worker_leave_requests", "(business_id)"),
    ("worker_invitations_business_id_created_at_idx", "worker_invitations", "(business_id, created_at desc)"),
    # A user's own haircut designs.
    ("haircut_designs_owner_id_idx", "haircut_designs", "(owner_id)"),
]


def upgrade() -> None:
    """Upgrade schema."""
    for name, table, definition in INDEXES:
        op.execute(f"create index if not exists {name} on {table} {definition}")


def downgrade() -> None:
    """Downgrade schema."""
    for name, _, _ in INDEXES:
        op.execute(f"drop index if exists {name}")
