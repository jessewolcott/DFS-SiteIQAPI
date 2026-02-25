# Flatten nested alerts to find error patterns across sites using requests directly — no pySiteIQ module required
import getpass
import requests
from collections import Counter

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

# Paginate through all tickets
page_size = 1000
offset    = 0
tickets   = []

while True:
    r = requests.get(
        f'{BASE_URI}/api/external/ticket',
        headers=headers,
        params={'status': 'All', 'pageLimit': page_size, 'pageOffset': offset},
        timeout=30,
    )
    r.raise_for_status()
    batch = r.json()
    tickets.extend(batch)
    if len(batch) < page_size:
        break
    offset += page_size

all_alerts = []
for t in tickets:
    for a in (t.get('alerts') or []):
        all_alerts.append({
            'TicketID':        t['ticketID'],
            'SiteName':        t.get('siteName'),
            'Component':       t.get('component'),
            'Dispenser':       t.get('dispenser'),
            'Error':           a.get('error'),
            'FuelingPosition': a.get('fuelingPosition'),
            'AlertOpened':     a.get('alertOpenTimestamp'),
            'AlertClosed':     a.get('alertCloseTimestamp'),
            'StillOpen':       a.get('alertCloseTimestamp') is None,
        })

print(f'Total alerts: {len(all_alerts)}\n')

# Top 10 error types
print('Top 10 error types:')
error_counts = Counter(a['Error'] for a in all_alerts)
for error, count in error_counts.most_common(10):
    print(f'  {count:>5}  {error}')

print()

# Still-open alerts
open_alerts = [a for a in all_alerts if a['StillOpen']]
print(f'Still open: {len(open_alerts)}\n')

# Fueling positions with 5+ alerts
print('Fueling positions with 5+ alerts:')
by_position = Counter(str(a['FuelingPosition']) for a in all_alerts if a['FuelingPosition'] is not None)
for pos, count in by_position.most_common():
    if count < 5:
        break
    print(f'  {count:>5}  position {pos}')
