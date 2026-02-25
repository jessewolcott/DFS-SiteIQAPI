# Pipeline filtering and grouping using requests directly — no pySiteIQ module required
import getpass
import requests
from collections import Counter
from datetime import datetime

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

# By component
print('Tickets by component:')
by_component = Counter(t.get('component', '') for t in tickets)
for component, count in by_component.most_common():
    print(f'  {count:>5}  {component}')

print()

# Top 10 sites
print('Top 10 sites:')
by_site = Counter(t.get('siteName', '') for t in tickets)
for site, count in by_site.most_common(10):
    print(f'  {count:>5}  {site}')

print()

# Tickets with 3+ alerts
heavy = [t for t in tickets if len(t.get('alerts') or []) >= 3]
print(f'Tickets with 3+ alerts: {len(heavy)}')
print(f'  {"ID":>8}  {"Site":<35}  {"Component":<20}  Alerts')
print('  ' + '-' * 75)
for t in heavy:
    print(f'  {t["ticketID"]:>8}  {t["siteName"]:<35}  {t["component"]:<20}  {len(t["alerts"])}')

print()

# Opened today
today_str    = datetime.now().strftime('%Y-%m-%d')
opened_today = [t for t in tickets if str(t.get('ticketOpenTimestamp', '')).startswith(today_str)]
print(f'Opened today: {len(opened_today)}')
