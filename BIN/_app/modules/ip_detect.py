"""LAN IPv4 detection and enumeration."""
import socket
import sys


def get_default_route_ip() -> str:
    """Return the IPv4 the OS would pick for outbound traffic, or 127.0.0.1."""
    # UDP connect() resolves the route table without sending a packet.
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def _list_ips_unix() -> list[str]:
    try:
        import fcntl
        import struct
    except ImportError:
        return []
    try:
        names = socket.if_nameindex()
    except OSError:
        return []
    ips: list[str] = []
    for _, name in names:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            packed = struct.pack("256s", name[:15].encode())
            # SIOCGIFADDR
            raw = fcntl.ioctl(s.fileno(), 0x8915, packed)
            ip = socket.inet_ntoa(raw[20:24])
            if ip and not ip.startswith("127."):
                ips.append(ip)
        except OSError:
            continue
        finally:
            s.close()
    return ips


def _list_ips_getaddrinfo() -> list[str]:
    ips: list[str] = []
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, family=socket.AF_INET):
            ip = info[4][0]
            if ip and not ip.startswith("127."):
                ips.append(ip)
    except OSError:
        pass
    return ips


def list_lan_ips() -> list[str]:
    """Return sorted unique non-loopback IPv4 addresses on this machine."""
    if sys.platform.startswith("linux") or sys.platform == "darwin":
        ips = _list_ips_unix() or _list_ips_getaddrinfo()
    else:
        ips = _list_ips_getaddrinfo()
    default = get_default_route_ip()
    if default and not default.startswith("127."):
        ips.append(default)
    return sorted(set(ips))


def get_lan_ip() -> str:
    """Return the default-route LAN IPv4, or 127.0.0.1 on failure."""
    return get_default_route_ip()
