# Pipeline filtering and grouping
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from collections import Counter
from datetime import datetime
try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets(status='All', all_pages=True)

# By component
print('Tickets by component:')
by_component = Counter(t.get('component', '') for t in tickets)
for component, count in by_component.most_common():
    print(f'  {count:>5}  {component}')

print()

# Top 10 sites
print('Top 10 sites:')
by_site = Counter(t.get('siteName', '') for t in tickets)
for site, count in by_site.most_common(10):
    print(f'  {count:>5}  {site}')

print()

# Tickets with 3+ alerts
heavy = [t for t in tickets if len(t.get('alerts') or []) >= 3]
print(f'Tickets with 3+ alerts: {len(heavy)}')
print(f'  {"ID":>8}  {"Site":<35}  {"Component":<20}  Alerts')
print('  ' + '-' * 75)
for t in heavy:
    print(f'  {t["ticketID"]:>8}  {t["siteName"]:<35}  {t["component"]:<20}  {len(t["alerts"])}')

print()

# Opened today
today_str = datetime.now().strftime('%Y-%m-%d')
opened_today = [t for t in tickets if str(t.get('ticketOpenTimestamp', '')).startswith(today_str)]
print(f'Opened today: {len(opened_today)}')
