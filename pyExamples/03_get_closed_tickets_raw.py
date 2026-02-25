# Closed tickets from the last 30 days, sorted newest first using requests directly — no pySiteIQ module required
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

# Paginate through all closed tickets
page_size = 1000
offset    = 0
closed    = []

while True:
    r = requests.get(
        f'{BASE_URI}/api/external/ticket',
        headers=headers,
        params={'status': 'Closed', 'pageLimit': page_size, 'pageOffset': offset},
        timeout=30,
    )
    r.raise_for_status()
    batch = r.json()
    closed.extend(batch)
    if len(batch) < page_size:
        break
    offset += page_size

closed.sort(key=lambda t: t.get('ticketOpenTimestamp', ''), reverse=True)
top20 = closed[:20]

print(f'Found {len(closed)} closed tickets — showing newest 20\n')
print(f'{"ID":>8}  {"Site":<35}  {"Component":<20}  {"Dispenser":<12}  Status')
print('-' * 90)
for t in top20:
    print(
        f'{t["ticketID"]:>8}  {t["siteName"]:<35}  {t["component"]:<20}'
        f'  {str(t.get("dispenser", "")):<12}  {t["ticketStatus"]}'
    )
