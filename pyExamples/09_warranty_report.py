# Warranty breakdown for open tickets
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from collections import Counter
from datetime import datetime, timedelta
try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets(status='InProgress', all_pages=True)

in_warranty  = [t for t in tickets if t.get('warrantyStatus') == 'In']
out_warranty = [t for t in tickets if t.get('warrantyStatus') == 'Out']

print(f'Under warranty:  {len(in_warranty)}')
print(f'Out of warranty: {len(out_warranty)}')
print()

# Expiring within 30 days
cutoff = (datetime.now() + timedelta(days=30)).strftime('%Y-%m-%d')
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
