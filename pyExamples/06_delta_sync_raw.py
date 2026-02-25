# Incremental sync using epoch timestamps using requests directly — no pySiteIQ module required
# Good for scheduled jobs that only need what changed since last run.
import getpass
import requests
from datetime import datetime, timezone

BASE_URI = 'https://dfs.site-iq.com'

# Authenticate
email    = input('Site-IQ email: ')
password = getpass.getpass('Password: ')

resp = requests.post(
    f'{BASE_URI}/api/web/auth/token',
    json={'email': email, 'password': password},
    timeout=30,
)
resp.raise_for_status()
token = resp.json()['token']

headers = {'Authorization': f'Bearer {token}'}

last_sync = datetime(2025, 8, 1, tzinfo=timezone.utc)
epoch     = int(last_sync.timestamp())

print(f'Fetching changes since {last_sync.isoformat()} (epoch {epoch})')

# Paginate through all changed tickets
page_size = 1000
offset    = 0
changed   = []

while True:
    r = requests.get(
        f'{BASE_URI}/api/external/ticket',
        headers=headers,
        params={'status': 'All', 'delta': epoch, 'pageLimit': page_size, 'pageOffset': offset},
        timeout=30,
    )
    r.raise_for_status()
    batch = r.json()
    changed.extend(batch)
    if len(batch) < page_size:
        break
    offset += page_size

print(f'Got {len(changed)} tickets\n')
print(f'{"ID":>8}  {"Site":<35}  {"Status":<18}  Component')
print('-' * 85)
for t in changed:
    print(f'{t["ticketID"]:>8}  {t["siteName"]:<35}  {t["ticketStatus"]:<18}  {t["component"]}')

# Record current time as the next delta marker
next_delta = int(datetime.now(timezone.utc).timestamp())
print(f'\nNext run, use delta={next_delta}')
