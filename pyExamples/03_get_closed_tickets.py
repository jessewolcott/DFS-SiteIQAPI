# Closed tickets from the last 30 days, sorted newest first
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    closed = client.get_tickets(status='Closed')

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
