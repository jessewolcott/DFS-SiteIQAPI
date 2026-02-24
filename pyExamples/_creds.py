# Credential helper for pyExamples.
# Uses the system keychain (keyring) when available — prompts once, then loads silently.
# Falls back to getpass on every run if keyring isn't installed.

import getpass

_SERVICE = 'SiteIQ'
_EMAIL_KEY = '__siteiq_email__'

try:
    import keyring as _keyring
    _HAS_KEYRING = True
except ImportError:
    _HAS_KEYRING = False


def get_credential() -> tuple:
    """Return (email, password), loading from the system keychain or prompting."""
    email = password = None

    if _HAS_KEYRING:
        email = _keyring.get_password(_SERVICE, _EMAIL_KEY)
        if email:
            password = _keyring.get_password(_SERVICE, email)

    if not email or not password:
        email = input('Site-IQ email: ').strip()
        password = getpass.getpass('Site-IQ password: ')
        if _HAS_KEYRING:
            _keyring.set_password(_SERVICE, _EMAIL_KEY, email)
            _keyring.set_password(_SERVICE, email, password)

    return email, password


def clear_credential() -> None:
    """Remove stored credentials from the keychain."""
    if not _HAS_KEYRING:
        print('keyring not available — nothing to clear')
        return
    email = _keyring.get_password(_SERVICE, _EMAIL_KEY)
    if email:
        _keyring.delete_password(_SERVICE, email)
    try:
        _keyring.delete_password(_SERVICE, _EMAIL_KEY)
    except Exception:
        pass
    print('Stored credentials cleared')
