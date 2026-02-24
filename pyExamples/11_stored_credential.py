# Non-interactive auth using the system keychain.
# On Windows: Windows Credential Manager.
# On macOS:   Keychain Access.
# On Linux:   libsecret / KWallet (via keyring package).
# Falls back to getpass prompting if keyring is unavailable.
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

# First run: prompts and saves to keychain.
# Subsequent runs: loads silently.
email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets()

print(f'Got {len(tickets)} in-progress tickets')

# To clear stored credentials, run:
#   from _creds import clear_credential; clear_credential()
