# Warranty breakdown for open tickets using requests directly — no pySiteIQ module required
import getpass
import requests
from collections import Counter
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

# Paginate through all in-progress tickets
page_size = 1000
offset    = 0
tickets   = []

while True:
    r = requests.get(
        f'{BASE_URI}/api/external/ticket',
        headers=headers,
        params={'status': 'InProgress', 'pageLimit': page_size, 'pageOffset': offset},
        timeout=30,
    )
    r.raise_for_status()
    batch = r.json()
    tickets.extend(batch)
    if len(batch) < page_size:
        break
    offset += page_size

in_warranty  = [t for t in tickets if t.get('warrantyStatus') == 'In']
out_warranty = [t for t in tickets if t.get('warrantyStatus') == 'Out']

print(f'Under warranty:  {len(in_warranty)}')
print(f'Out of warranty: {len(out_warranty)}')
print()

# Expiring within 30 days
cutoff        = (datetime.now() + timedelta(days=30)).strftime('%Y-%m-%d')
expiring_soon = [
    t for t in in_warranty
    if t.get('warrantyDate') and t['warrantyDate'] <= cutoff
]

if expiring_soon:
    print(f'{len(expiring_soon)} warranties expiring within 30 days:')
    print(f'  {"ID":>8}  {"Site":<35}  {"Warranty Date":<15}  Component')
    print('  ' + '-' * 75)
    for t in expiring_soon:
        print(f'  {t["ticketID"]:>8}  {t["siteName"]:<35}  {t.get("warrantyDate", ""):<15}  {t["component"]}')
    print()

# Out-of-warranty by site
print('Out-of-warranty by site:')
by_site = Counter(t.get('siteName', '') for t in out_warranty)
for site, count in by_site.most_common():
    print(f'  {count:>5}  {site}')
