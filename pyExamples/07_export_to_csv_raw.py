# Flatten tickets and dump to CSV using requests directly — no pySiteIQ module required
import csv
import getpass
import pathlib
import requests
from datetime import datetime

BASE_URI = 'https://dfs.site-iq.com'
out_path = pathlib.Path(__file__).parent / 'SiteIQ-Tickets.csv'

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

# Flatten — alerts is nested, so only ticket-level fields go to CSV
rows = []
for t in tickets:
    rows.append({
        'TicketID':       t['ticketID'],
        'Opened':         t.get('ticketOpenTimestamp'),
        'SiteID':         t.get('siteID'),
        'SiteName':       t.get('siteName'),
        'Company':        t.get('companyName'),
        'Address':        t.get('address'),
        'Status':         t.get('ticketStatus'),
        'Component':      t.get('component'),
        'Dispenser':      t.get('dispenser'),
        'WarrantyStatus': t.get('warrantyStatus'),
        'WarrantyDate':   t.get('warrantyDate'),
        'AlertCount':     len(t.get('alerts') or []),
    })

if rows:
    with open(out_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

print(f'Wrote {len(rows)} rows to {out_path}')
