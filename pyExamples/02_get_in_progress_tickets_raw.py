# Simplest query — default status is InProgress using requests directly — no pySiteIQ module required
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

# Fetch in-progress tickets (API default: status=InProgress, last 30 days)
r = requests.get(f'{BASE_URI}/api/external/ticket', headers=headers, timeout=30)
r.raise_for_status()
tickets = r.json()

print(f'Found {len(tickets)} in-progress tickets\n')
print(f'{"ID":>8}  {"Site":<35}  {"Component":<20}  Status')
print('-' * 80)
for t in tickets:
    print(f'{t["ticketID"]:>8}  {t["siteName"]:<35}  {t["component"]:<20}  {t["ticketStatus"]}')
