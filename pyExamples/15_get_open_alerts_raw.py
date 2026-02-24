# Get open alerts using requests directly — no pySiteIQ module required
import getpass
import requests

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

# Flatten to open alerts only
open_alerts = []
for t in tickets:
    for a in (t.get('alerts') or []):
        if a.get('alertCloseTimestamp') is None:
            open_alerts.append({
                'TicketID':        t['ticketID'],
                'SiteName':        t.get('siteName'),
                'Component':       t.get('component'),
                'Dispenser':       t.get('dispenser'),
                'Error':           a.get('error'),
                'FuelingPosition': a.get('fuelingPosition'),
                'AlertOpened':     a.get('alertOpenTimestamp'),
            })

open_alerts.sort(key=lambda a: a['SiteName'] or '')

print(f'Open alerts: {len(open_alerts)}\n')

header = f"{'TicketID':>10}  {'SiteName':<20}  {'Component':<15}  {'Dispenser':<10}  {'FP':>3}  {'AlertOpened':<19}  Error"
print(header)
print('-' * len(header))

for a in open_alerts:
    print(
        f"{a['TicketID']:>10}  "
        f"{str(a['SiteName'] or ''):<20}  "
        f"{str(a['Component'] or ''):<15}  "
        f"{str(a['Dispenser'] or ''):<10}  "
        f"{str(a['FuelingPosition'] or ''):>3}  "
        f"{str(a['AlertOpened'] or ''):<19}  "
        f"{a['Error'] or ''}"
    )
