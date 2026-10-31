"""Interactive authenticated session. Credentials stay in process memory only.

stdin JSON: {"script": "local LF script", "remote": "/tmp/name.sh"},
or {"command": "simple read-only command"}, or {"put": "local", "remote": "path"}.
"""
import getpass
import hashlib
import json
from pathlib import Path
import shlex
import sys
import time
import uuid
import threading
import paramiko
import argparse

def secret(prompt):
    # Windows getpass reads the console directly even when stdin is a pipe.
    # Non-interactive controller sessions supply the same two lines via stdin.
    if sys.stdin.isatty():
        return getpass.getpass(prompt)
    return sys.stdin.readline().rstrip('\r\n')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--host',required=True,help='Target from the currently authorized SSH command')
    args=parser.parse_args()
    jump_user=secret('Jump username/token (hidden): ')
    target_password=secret('Target password (hidden): ')
    if not jump_user or not target_password:
        raise SystemExit('Missing credentials on stdin; refusing any network connection')
    transport=paramiko.Transport(('113.47.8.48',2234))
    transport.start_client(timeout=25)
    try:
        transport.auth_none(jump_user)
    except paramiko.BadAuthenticationType as exc:
        if 'password' not in exc.allowed_types:raise
        transport.auth_password(jump_user,'')
    channel=transport.open_channel('direct-tcpip',(args.host,22),('127.0.0.1',0),timeout=25)
    client=paramiko.SSHClient();client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(args.host,username='root',password=target_password,sock=channel,
                   allow_agent=False,look_for_keys=False,timeout=25,banner_timeout=25,auth_timeout=25)
    del jump_user,target_password
    transport.set_keepalive(20)
    client.get_transport().set_keepalive(20)
    key=client.get_transport().get_remote_server_key()
    print(json.dumps({'connected':True,'target':args.host,'target_hostkey_sha256':hashlib.sha256(key.asbytes()).hexdigest()}),flush=True)
    sftp=client.open_sftp()
    connected_at=time.monotonic()
    heartbeat=client.get_transport().open_session()
    heartbeat.exec_command("while sleep 20; do printf 't5-ssh-alive\\n' || exit; done")
    heartbeat_count=0
    def drain_heartbeat():
        nonlocal heartbeat_count
        try:
            while data:=heartbeat.recv(1024):
                heartbeat_count+=data.count(b't5-ssh-alive\n')
        except (OSError,EOFError):
            pass
    threading.Thread(target=drain_heartbeat,daemon=True).start()
    def connection_state():
        return {'jump_active':transport.is_active(),
                'target_active':client.get_transport().is_active(),
                'connected_seconds':round(time.monotonic()-connected_at,1),
                'remote_heartbeats_received':heartbeat_count}
    def remote_digest(remote):
        digest=hashlib.sha256()
        with sftp.open(remote,'rb') as handle:
            while chunk:=handle.read(1024*1024):digest.update(chunk)
        return digest.hexdigest()
    def upload_verified(local,remote):
        payload=Path(local).read_bytes()
        if Path(local).suffix in ('.sh','.cmd') or Path(remote).suffix in ('.sh','.cmd'):
            if b'\r' in payload or payload.startswith(b'\xef\xbb\xbf'):
                raise ValueError('Reject non-LF or BOM Linux script before upload')
            payload.decode('utf-8')
        expected=hashlib.sha256(payload).hexdigest()
        try:
            existing=remote_digest(remote)
        except FileNotFoundError:
            existing=None
        if existing is not None:
            if existing!=expected:raise FileExistsError('Preserve differing remote file: '+remote)
            print(json.dumps({'existing_upload_verified':remote,'sha256':expected}),flush=True)
            return
        partial=remote+'.upload-'+uuid.uuid4().hex+'.part'
        sftp.put(local,partial)
        if remote_digest(partial)!=expected:raise ValueError('Uploaded byte checksum mismatch; temporary file preserved')
        sftp.rename(partial,remote)
        print(json.dumps({'uploaded':remote,'sha256':expected,'remote_bytes_verified':True}),flush=True)
    def run(command, timeout_seconds=180):
        _,stdout,stderr=client.exec_command(command,timeout=120)
        channel=stdout.channel
        started=time.monotonic()
        while not channel.exit_status_ready() or channel.recv_ready() or channel.recv_stderr_ready():
            if channel.recv_ready():print(channel.recv(65536).decode('utf-8',errors='replace'),end='',flush=True)
            if channel.recv_stderr_ready():print(channel.recv_stderr(65536).decode('utf-8',errors='replace'),end='',flush=True)
            if time.monotonic()-started>timeout_seconds:
                # Keep the authenticated transport alive. Closing this command
                # channel does NOT assert that its remote child was terminated.
                channel.close()
                print(json.dumps({'command_timeout_seconds':timeout_seconds,'remote_process_state':'must inspect before retry'}),flush=True)
                return
            time.sleep(.05)
        print(json.dumps({'exit_code':channel.recv_exit_status()}),flush=True)
    for line in sys.stdin:
        if not line.strip():continue
        try:
            item=json.loads(line)
            if item.get('exit'):break
            if not transport.is_active() or not client.get_transport().is_active():
                raise ConnectionError('Inactive SSH transport; refusing new transfer or remote command')
            if item.get('status'):
                print(json.dumps(connection_state()),flush=True)
            elif 'script' in item:
                payload=Path(item['script']).read_bytes()
                if b'\r' in payload or payload.startswith(b'\xef\xbb\xbf'):raise ValueError('reject non-LF or BOM script')
                payload.decode('utf-8')
                remote=item['remote']
                upload_verified(item['script'],remote)
                sftp.chmod(remote,0o700)
                if item.get('background'):
                    logfile=shlex.quote(item['log'])
                    run('bash -n '+shlex.quote(remote)+' && (nohup bash '+shlex.quote(remote)+
                        ' > '+logfile+' 2>&1 < /dev/null & echo $!)')
                else:
                    run('bash -n '+shlex.quote(remote)+' && bash '+shlex.quote(remote))
            elif 'put' in item:
                upload_verified(item['put'],item['remote'])
            elif 'get' in item:
                destination=Path(item['local'])
                destination.parent.mkdir(parents=True,exist_ok=True)
                partial=destination.with_name(destination.name+'.part')
                sftp.get(item['get'],str(partial))
                if destination.exists():
                    if destination.read_bytes()!=partial.read_bytes():
                        raise FileExistsError(f'Preserve existing evidence and new partial: {destination}')
                    partial.unlink()
                else:
                    partial.rename(destination)
                print(json.dumps({'downloaded':str(destination),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}),flush=True)
            elif 'command' in item:run(item['command'],item.get('timeout_seconds',180))
            else:raise ValueError('unknown request')
        except Exception as exc:
            print(json.dumps({'error':f'{type(exc).__name__}: {exc}',**connection_state()}),flush=True)
            if not transport.is_active() or not client.get_transport().is_active():
                print(json.dumps({'session_closed':True,'next_action':'reconnect and inspect remote state before retry'}),flush=True)
                break
    heartbeat.close();sftp.close();client.close();transport.close()

if __name__=='__main__':main()
