# Simplest query — default status is InProgress, default window is 30 days
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets()

print(f'Found {len(tickets)} in-progress tickets\n')
print(f'{"ID":>8}  {"Site":<35}  {"Component":<20}  Status')
print('-' * 80)
for t in tickets:
    print(f'{t["ticketID"]:>8}  {t["siteName"]:<35}  {t["component"]:<20}  {t["ticketStatus"]}')
