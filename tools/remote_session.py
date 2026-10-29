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
import paramiko

def secret(prompt):
    # Windows getpass reads the console directly even when stdin is a pipe.
    # Non-interactive controller sessions supply the same two lines via stdin.
    if sys.stdin.isatty():
        return getpass.getpass(prompt)
    return sys.stdin.readline().rstrip('\r\n')


def main():
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
    channel=transport.open_channel('direct-tcpip',('199.103.54.86',22),('127.0.0.1',0),timeout=25)
    client=paramiko.SSHClient();client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect('199.103.54.86',username='root',password=target_password,sock=channel,
                   allow_agent=False,look_for_keys=False,timeout=25,banner_timeout=25,auth_timeout=25)
    del jump_user,target_password
    transport.set_keepalive(20)
    client.get_transport().set_keepalive(20)
    key=client.get_transport().get_remote_server_key()
    print(json.dumps({'connected':True,'target_hostkey_sha256':hashlib.sha256(key.asbytes()).hexdigest()}),flush=True)
    sftp=client.open_sftp()
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
            if 'script' in item:
                payload=Path(item['script']).read_bytes()
                if b'\r' in payload or payload.startswith(b'\xef\xbb\xbf'):raise ValueError('reject non-LF or BOM script')
                payload.decode('utf-8')
                remote=item['remote']
                with sftp.file(remote,'wb') as handle:handle.write(payload)
                sftp.chmod(remote,0o700)
                if item.get('background'):
                    logfile=shlex.quote(item['log'])
                    run('bash -n '+shlex.quote(remote)+' && (nohup bash '+shlex.quote(remote)+
                        ' > '+logfile+' 2>&1 < /dev/null & echo $!)')
                else:
                    run('bash -n '+shlex.quote(remote)+' && bash '+shlex.quote(remote))
            elif 'put' in item:
                sftp.put(item['put'],item['remote'])
                print(json.dumps({'uploaded':item['remote'],'sha256':hashlib.sha256(Path(item['put']).read_bytes()).hexdigest()}),flush=True)
            elif 'get' in item:
                destination=Path(item['local'])
                partial=destination.with_name(destination.name+'.part')
                sftp.get(item['get'],str(partial))
                partial.replace(destination)
                print(json.dumps({'downloaded':str(destination),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}),flush=True)
            elif 'command' in item:run(item['command'],item.get('timeout_seconds',180))
            else:raise ValueError('unknown request')
        except Exception as exc:print(json.dumps({'error':f'{type(exc).__name__}: {exc}'}),flush=True)
    sftp.close();client.close();transport.close()

if __name__=='__main__':main()
