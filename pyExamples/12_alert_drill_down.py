# Flatten nested alerts to find error patterns across sites
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from collections import Counter
from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets(status='All', all_pages=True)

all_alerts = []
for t in tickets:
    for a in (t.get('alerts') or []):
        all_alerts.append({
            'TicketID':        t['ticketID'],
            'SiteName':        t.get('siteName'),
            'Component':       t.get('component'),
            'Dispenser':       t.get('dispenser'),
            'Error':           a.get('error'),
            'FuelingPosition': a.get('fuelingPosition'),
            'AlertOpened':     a.get('alertOpenTimestamp'),
            'AlertClosed':     a.get('alertCloseTimestamp'),
            'StillOpen':       a.get('alertCloseTimestamp') is None,
        })

print(f'Total alerts: {len(all_alerts)}\n')

# Top 10 error types
print('Top 10 error types:')
error_counts = Counter(a['Error'] for a in all_alerts)
for error, count in error_counts.most_common(10):
    print(f'  {count:>5}  {error}')

print()

# Still-open alerts
open_alerts = [a for a in all_alerts if a['StillOpen']]
print(f'Still open: {len(open_alerts)}\n')

# Fueling positions with 5+ alerts
print('Fueling positions with 5+ alerts:')
by_position = Counter(str(a['FuelingPosition']) for a in all_alerts if a['FuelingPosition'] is not None)
for pos, count in by_position.most_common():
    if count < 5:
        break
    print(f'  {count:>5}  position {pos}')
