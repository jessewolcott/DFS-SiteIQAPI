# Manual pagination loop using requests directly — no pySiteIQ module required
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

# Manual: 50 at a time
page_size   = 50
offset      = 0
all_tickets = []

while True:
    r = requests.get(
        f'{BASE_URI}/api/external/ticket',
        headers=headers,
        params={'status': 'All', 'pageLimit': page_size, 'pageOffset': offset},
        timeout=30,
    )
    r.raise_for_status()
    batch = r.json()
    all_tickets.extend(batch)
    print(f'  Offset {offset:>5}: got {len(batch)} tickets')
    if len(batch) < page_size:
        break
    offset += page_size

print(f'Total: {len(all_tickets)} tickets')
