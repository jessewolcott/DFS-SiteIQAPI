# Non-interactive auth using the system keychain with requests directly — no pySiteIQ module required
# On Windows: Windows Credential Manager.
# On macOS:   Keychain Access.
# On Linux:   libsecret / KWallet (via keyring package).
# Falls back to getpass prompting if keyring is unavailable.
import getpass
import requests

BASE_URI    = 'https://dfs.site-iq.com'
SERVICE     = 'siteiq'

try:
    import keyring
    email    = keyring.get_password(SERVICE, 'email')
    password = keyring.get_password(SERVICE, 'password')
    if not email or not password:
        email    = input('Site-IQ email: ')
        password = getpass.getpass('Password: ')
        keyring.set_password(SERVICE, 'email',    email)
        keyring.set_password(SERVICE, 'password', password)
        print('Credentials saved to keychain')
except ModuleNotFoundError:
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

# Fetch in-progress tickets
r = requests.get(f'{BASE_URI}/api/external/ticket', headers=headers, timeout=30)
r.raise_for_status()
tickets = r.json()

print(f'Got {len(tickets)} in-progress tickets')

# To clear stored credentials, run:
#   import keyring; keyring.delete_password('siteiq', 'email'); keyring.delete_password('siteiq', 'password')
