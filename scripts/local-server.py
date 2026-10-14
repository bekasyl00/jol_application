#!/usr/bin/env python3
"""Run only demo-jol emulators. Never uses the real project's default alias."""
import argparse
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent

def allowed(host):
    try:
        ip = ipaddress.IPv4Address(host)
        return str(ip) == host and any(ip in ipaddress.ip_network(net) for net in
            ['127.0.0.1/32', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'])
    except ValueError:
        return False

def mac_address():
    for interface in ['en0', 'en1']:
        result = subprocess.run(['ipconfig', 'getifaddr', interface], capture_output=True, text=True)
        address = result.stdout.strip()
        if allowed(address):
            return address
    raise RuntimeError('Подключите Mac к Wi-Fi или укажите --host 127.0.0.1 для симулятора.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', help='Private IPv4 address of this Mac; default: Wi-Fi address')
    parser.add_argument('--test', action='store_true', help='Run isolated HTTP integration tests on alternate ports')
    args = parser.parse_args()
    host = '127.0.0.1' if args.test else (args.host or mac_address())
    if not allowed(host):
        raise RuntimeError('Допустим только частный IPv4-адрес этого Mac или 127.0.0.1.')
    for path in ['node_modules/.bin/firebase', 'backend/functions/node_modules/firebase-admin']:
        if not (ROOT/path).exists():
            raise RuntimeError('Сначала выполните npm ci и npm ci --prefix backend/functions.')
    folder = ROOT/'.local-emulators'/('tests' if args.test else 'development')
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (folder/'server.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise RuntimeError('Этот сервер уже запущен. Используйте его окно терминала.') from None
    ports = {'auth': 9299, 'firestore': 8280, 'functions': 5201, 'storage': 9399, 'hub': 4401, 'logging': 4501, 'eventarc': 9300, 'tasks': 9500} if args.test else {
        'auth': 9099, 'firestore': 8080, 'functions': 5001, 'storage': 9199, 'hub': 4400, 'logging': 4500, 'ui': 4000, 'eventarc': 9298, 'tasks': 9499}
    emulators = {name: {'host': '127.0.0.1' if name in ['hub', 'logging', 'ui', 'eventarc', 'tasks'] else host, 'port': port} for name, port in ports.items()}
    for name, config in emulators.items():
        try:
            with socket.socket() as listener:
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                listener.bind((config['host'], config['port']))
                listener.listen(1)
        except OSError:
            raise RuntimeError(f"Порт {config['port']} ({name}) занят или адрес не принадлежит этому Mac. Сервер не запущен.") from None
    emulators['ui'] = {**emulators.get('ui', {}), 'enabled': not args.test}
    emulators['firestore']['websocketPort'] = 9151 if args.test else 9150
    config = json.loads((ROOT/'firebase.json').read_text())
    config['emulators'] = emulators
    # Firebase requires source/rules to stay inside the config's project directory.
    config_path = ROOT/('.local-emulators-tests.json' if args.test else '.local-emulators-development.json')
    config_path.write_text(json.dumps(config, indent=2) + '\n')
    command = [str(ROOT/'node_modules/.bin/firebase'), 'emulators:exec' if args.test else 'emulators:start',
        '--project', 'demo-jol', '--config', str(config_path), '--only', 'auth,firestore,functions,storage']
    env = os.environ.copy()
    env.pop('GOOGLE_APPLICATION_CREDENTIALS', None)
    # Xcode and the simulator can make first-time module loading exceed the CLI's 10s default.
    # Otherwise Firebase may report emulators ready while no callable functions were loaded.
    env.setdefault('FUNCTIONS_DISCOVERY_TIMEOUT', '120')
    if args.test:
        env['JOL_LOCAL_FUNCTIONS_HOST'] = f'{host}:5201'
        command.append('node --test backend/tests/local-http.test.js')
    else:
        signing = ROOT/'App/Resources/LocalSigning.xcconfig'
        content = signing.read_text() if signing.exists() else ''
        content = re.sub(r'^JOL_EMULATOR_HOST\s*=.*\n?', '', content, flags=re.MULTILINE)
        temporary = signing.with_suffix('.xcconfig.tmp')
        temporary.write_text(content.rstrip() + f'\nJOL_EMULATOR_HOST = {host}\n')
        temporary.replace(signing)
        data = folder/'data'
        if (data/'firebase-export-metadata.json').exists():
            command += ['--import', str(data)]
        command += ['--export-on-exit', str(data)]
        print(f'Jol Local: {host}. В Xcode выберите JolParcelLocal и нажмите Run.\n'
              'Только тестовые данные в доверенной Wi-Fi сети. Mac должен оставаться включённым.\n'
              'Ctrl+C сохранит данные и остановит сервер. Панель: http://127.0.0.1:4000', flush=True)
    process = subprocess.Popen(command, cwd=ROOT, env=env)
    try:
        return process.wait()
    except KeyboardInterrupt:
        # The foreground terminal sends SIGINT to both processes. Let Firebase export safely.
        return process.wait()

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, FileNotFoundError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
