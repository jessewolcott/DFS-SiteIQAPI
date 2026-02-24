# Basic connection lifecycle
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

client = SiteIQClient()
session = client.connect(email, password)
print('Connected:       ', session['connected'])
print('Email:           ', session['email'])
print('Base URI:        ', session['base_uri'])
print('is_connected():  ', client.is_connected())

client.disconnect()
print('After disconnect:', client.is_connected())
