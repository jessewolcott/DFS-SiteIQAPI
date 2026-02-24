# Custom date range queries
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from datetime import datetime, timedelta
from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)

    # Specific week
    tickets = client.get_tickets(status='All', start_date='2025-01-01', end_date='2025-01-07')
    print(f'Jan 1–7 2025: {len(tickets)} tickets')
    for t in tickets:
        print(f'  {t["ticketID"]:>8}  {t["siteName"]:<35}  {t["ticketStatus"]}  {t["component"]}')

    print()

    # Rolling last 7 days
    today = datetime.now()
    week_ago = today - timedelta(days=7)
    recent = client.get_tickets(status='All', start_date=week_ago, end_date=today)
    print(f'Last 7 days: {len(recent)} tickets')
