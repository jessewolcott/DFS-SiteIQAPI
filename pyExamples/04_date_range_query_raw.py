# Custom date range queries using requests directly — no pySiteIQ module required
import getpass
import requests
from datetime import datetime, timedelta

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

# Specific week
r = requests.get(
    f'{BASE_URI}/api/external/ticket',
    headers=headers,
    params={'status': 'All', 'startDate': '2025-01-01', 'endDate': '2025-01-07'},
    timeout=30,
)
r.raise_for_status()
tickets = r.json()

print(f'Jan 1–7 2025: {len(tickets)} tickets')
for t in tickets:
    print(f'  {t["ticketID"]:>8}  {t["siteName"]:<35}  {t["ticketStatus"]}  {t["component"]}')

print()

# Rolling last 7 days
today    = datetime.now()
week_ago = today - timedelta(days=7)

r = requests.get(
    f'{BASE_URI}/api/external/ticket',
    headers=headers,
    params={
        'status':    'All',
        'startDate': week_ago.strftime('%Y-%m-%d'),
        'endDate':   today.strftime('%Y-%m-%d'),
    },
    timeout=30,
)
r.raise_for_status()
recent = r.json()

print(f'Last 7 days: {len(recent)} tickets')
