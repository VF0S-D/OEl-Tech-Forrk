"""LAN IP detection via PowerShell default-route interface."""
import subprocess


def get_lan_ip() -> str:
    """Return the LAN IPv4 address of the default-route NIC, or 127.0.0.1 on failure."""
    ps = (
        "$idx=(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | "
        "Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex; "
        "(Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4).IPAddress"
    )
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            capture_output=True, text=True, timeout=10,
        )
        ip = result.stdout.strip()
        # Validate: must be dotted-decimal IPv4
        parts = ip.split(".")
        if len(parts) == 4 and all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
            return ip
    except Exception:
        pass
    return "127.0.0.1"
