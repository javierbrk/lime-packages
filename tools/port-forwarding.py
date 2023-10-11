#!/usr/bin/env python3
# Tcp Port Forwarding (Reverse Proxy)
#
# For link-local IPv6 address, such as router emergency recovery, etc.
# Workaround for https://stackoverflow.com/questions/45299648/how-to-access-devices-with-ipv6-link-local-address-from-browserlike-ie-firefox
#
# Usage: python3 forward.py --listen-host 127.0.0.1 --listen-port 8443 --connect-host 'fe80::abcd:abcd:beef:beef%enp0s0' --connect-port 443

import socket
import threading
import argparse
import logging


format = '%(asctime)s - %(filename)s:%(lineno)d - %(levelname)s: %(message)s'
logging.basicConfig(level=logging.INFO, format=format)

def transfer(src, dst, direction):
    while True:
        try:
            buffer = src.recv(4096)
            if len(buffer) > 0:
                dst.send(buffer)
        except Exception as e:
            logging.error(repr(e))
            break
    src.close()
    dst.close()


def server(local_host, local_port, remote_host, remote_port, ipv6=False):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((local_host, local_port))
    server_socket.listen(0x40)
    logging.info(f"Server started {local_host, local_port}")
    logging.info(f"Connect to {local_host, local_port} to get the content of {remote_host, remote_port}")

    # From https://stackoverflow.com/a/4030559/13843585
    inet_type = socket.AF_INET6 if ipv6 else socket.AF_INET
    addrinfo = socket.getaddrinfo(remote_host, remote_port, inet_type, socket.SOCK_STREAM)
    logging.info(f"dst addrinfo {addrinfo}")
    (family, socktype, proto, canonname, sockaddr) = addrinfo[0]
    while True:
        src_socket, src_address = server_socket.accept()
        logging.info(f"[Establishing] {src_address} -> {local_host, local_port} -> ? -> {remote_host, remote_port}")
        try:
            dst_socket = socket.socket(family, socktype, proto)
            dst_socket.connect(sockaddr)
            logging.info(f"[OK] {src_address} -> {local_host, local_port} -> {dst_socket.getsockname()} -> {remote_host, remote_port}")
            s = threading.Thread(target=transfer, args=(dst_socket, src_socket, False))
            r = threading.Thread(target=transfer, args=(src_socket, dst_socket, True))
            s.start()
            r.start()
        except Exception as e:
            logging.error(repr(e))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-host", help="the host to listen", required=True)
    parser.add_argument("--listen-port", type=int, help="the port to bind", required=True)
    parser.add_argument("--connect-host", help="the target host to connect", required=True)
    parser.add_argument("--connect-port", type=int, help="the target port to connect", required=True)
    parser.add_argument("--ipv6", type=bool, help="whether destination host is ipv6", default=True)
    args = parser.parse_args()
    server(args.listen_host, args.listen_port,
           args.connect_host, args.connect_port, args.ipv6)


if __name__ == "__main__":
    main()