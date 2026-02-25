# Basic connection lifecycle using requests directly — no pySiteIQ module required
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

print('Connected:      ', True)
print('Email:          ', email)
print('Base URI:       ', BASE_URI)
print('Has token:      ', bool(token))

# Tokens are short-lived; there is no explicit logout endpoint
print('Disconnected (token discarded)')
