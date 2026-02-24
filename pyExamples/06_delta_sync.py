# Incremental sync using epoch timestamps.
# Good for scheduled jobs that only need what changed since last run.
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from datetime import datetime, timezone
from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

last_sync = datetime(2025, 8, 1, tzinfo=timezone.utc)
epoch = int(last_sync.timestamp())

print(f'Fetching changes since {last_sync.isoformat()} (epoch {epoch})')

with SiteIQClient() as client:
    client.connect(email, password)
    changed = client.get_tickets(status='All', delta=epoch, all_pages=True)

print(f'Got {len(changed)} tickets\n')
print(f'{"ID":>8}  {"Site":<35}  {"Status":<18}  Component')
print('-' * 85)
for t in changed:
    print(f'{t["ticketID"]:>8}  {t["siteName"]:<35}  {t["ticketStatus"]:<18}  {t["component"]}')

# Record current time as the next delta marker
next_delta = int(datetime.now(timezone.utc).timestamp())
print(f'\nNext run, use delta={next_delta}')
