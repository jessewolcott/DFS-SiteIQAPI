# Retrieve only unresolved (still-open) alerts across all tickets
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
    tickets = client.get_tickets(status='All', all_pages=True)

open_alerts = []
for t in tickets:
    for a in (t.get('alerts') or []):
        if a.get('alertCloseTimestamp') is None:
            open_alerts.append({
                'TicketID':        t['ticketID'],
                'SiteName':        t.get('siteName'),
                'Component':       t.get('component'),
                'Dispenser':       t.get('dispenser'),
                'Error':           a.get('error'),
                'FuelingPosition': a.get('fuelingPosition'),
                'AlertOpened':     a.get('alertOpenTimestamp'),
            })

open_alerts.sort(key=lambda a: a['SiteName'] or '')

print(f'Open alerts: {len(open_alerts)}\n')

header = f"{'TicketID':>10}  {'SiteName':<20}  {'Component':<15}  {'Dispenser':<10}  {'FP':>3}  {'AlertOpened':<19}  Error"
print(header)
print('-' * len(header))

for a in open_alerts:
    print(
        f"{a['TicketID']:>10}  "
        f"{str(a['SiteName'] or ''):<20}  "
        f"{str(a['Component'] or ''):<15}  "
        f"{str(a['Dispenser'] or ''):<10}  "
        f"{str(a['FuelingPosition'] or ''):>3}  "
        f"{str(a['AlertOpened'] or ''):<19}  "
        f"{a['Error'] or ''}"
    )
