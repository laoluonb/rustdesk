"""Repair only the version metadata of the four known v1.5.8 RPM assets."""
import hashlib
import json
import os
from pathlib import Path
import subprocess


def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def query(path, fmt):
    return run('rpm', '-qp', '--queryformat', fmt, str(path))


def extract(path, destination):
    destination.mkdir(parents=True)
    with subprocess.Popen(['rpm2cpio', str(path.resolve())], stdout=subprocess.PIPE) as proc:
        subprocess.run(['cpio', '-idm', '--quiet', '--no-absolute-filenames'], stdin=proc.stdout, cwd=destination, check=True)
        proc.stdout.close()
        assert proc.wait() == 0


def inventory(root):
    result = {}
    for p in root.rglob('*'):
        if p.is_symlink():
            result[str(p.relative_to(root))] = ('link', os.readlink(p))
        elif p.is_file():
            result[str(p.relative_to(root))] = (p.stat().st_mode & 0o7777, hashlib.sha256(p.read_bytes()).hexdigest())
    return result


root = Path.cwd()
release = json.loads(run('gh', 'api', 'repos/' + os.environ['GH_REPO'] + '/releases/tags/v1.5.8'))
assert not release['draft'] and release['target_commitish'] == 'faee9b8cfb735a047c1bba8208751bbdc0019f76'
assets = {a['name']: a for a in release['assets']}
work = root / 'rpm-repair'
work.mkdir()
updated = []
for arch in ('x86_64', 'aarch64'):
    for suffix in ('', '-suse'):
        name = f'rustdesk-1.5.7-0.{arch}{suffix}.rpm'
        asset = assets[name]
        subprocess.run(['gh', 'release', 'download', 'v1.5.8', '-p', name, '-D', str(work)], check=True)
        old = work / name
        assert 'sha256:' + hashlib.sha256(old.read_bytes()).hexdigest() == asset['digest']
        assert query(old, '%{VERSION}') == '1.5.7'
        assert query(old, '%{ARCH}') == arch
        folder = work / (arch + (suffix or '-fedora'))
        payload = folder / 'payload'
        extract(old, payload)
        source = (root / ('res/rpm-flutter' + suffix + '.spec')).read_text()
        header = source.split('%description')[0]
        header = '\n'.join(line for line in header.splitlines() if not line.startswith(('Requires:', 'Provides:', 'Recommends:')))
        requires = run('rpm', '-qp', '--requires', str(old)).splitlines()
        provides = run('rpm', '-qp', '--provides', str(old)).splitlines()
        recommends = run('rpm', '-qp', '--recommends', str(old)).splitlines()
        header += '\nAutoReqProv: no\n'
        for label, values in [('Requires', requires), ('Provides', provides), ('Recommends', recommends)]:
            for value in values:
                if not value or value.startswith('rpmlib('):
                    continue
                if label == 'Provides' and value.startswith(('rustdesk =', 'rustdesk(')):
                    value = value.replace('1.5.7-0', '1.5.8-0')
                header += f'{label}: {value}\n'
        files_and_scripts = '%files\n/usr/lib/.build-id\n' + source.split('%files', 1)[1]
        spec = folder / 'repaired.spec'
        spec.write_text(header + '\n%description\nThe best open-source remote desktop client software, written in Rust.\n%prep\n%build\n%install\nmkdir -p "%{buildroot}"\ncp -a "' + str(payload) + '/." "%{buildroot}/"\n' + files_and_scripts)
        subprocess.run(['rpmbuild', '-bb', str(spec), '--target', arch, '--define', '_topdir ' + str(folder / 'build'), '--define', '__os_install_post %{nil}', '--define', '_build_id_links none', '--define', 'debug_package %{nil}'], check=True)
        built = folder / 'build' / 'RPMS' / arch / f'rustdesk-1.5.8-0.{arch}.rpm'
        assert query(built, '%{VERSION}') == '1.5.8'
        unpacked = folder / 'verified'
        extract(built, unpacked)
        assert inventory(payload) == inventory(unpacked), 'Payload changed'
        for tag in ['PREIN', 'POSTIN', 'PREUN', 'POSTUN', 'PREINPROG', 'POSTINPROG', 'PREUNPROG', 'POSTUNPROG']:
            assert query(old, '%{' + tag + '}') == query(built, '%{' + tag + '}'), tag
        assert set(requires) == set(run('rpm', '-qp', '--requires', str(built)).splitlines()), 'Dependencies changed'
        new = work / f'rustdesk-1.5.8-0.{arch}{suffix}.rpm'
        new.write_bytes(built.read_bytes())
        updated.append((name, new))
        print('Verified unchanged RPM payload and scripts:', new.name, flush=True)

# Upload all replacements before removing the four known incorrect assets.
for old_name, new in updated:
    subprocess.run(['gh', 'release', 'upload', 'v1.5.8', str(new), '--clobber'], check=True)
remote = json.loads(run('gh', 'api', f"repos/{os.environ['GH_REPO']}/releases/{release['id']}/assets?per_page=100"))
for _, new in updated:
    match = next(a for a in remote if a['name'] == new.name)
    assert match['digest'] == 'sha256:' + hashlib.sha256(new.read_bytes()).hexdigest()
for old_name, _ in updated:
    run('gh', 'api', '--method', 'DELETE', f"repos/{os.environ['GH_REPO']}/releases/assets/{assets[old_name]['id']}")
remote = json.loads(run('gh', 'api', f"repos/{os.environ['GH_REPO']}/releases/{release['id']}/assets?per_page=100"))
manifest = work / 'SHA256SUMS.txt'
lines = []
for asset in sorted(remote, key=lambda a: a['name']):
    if asset['name'] == manifest.name:
        continue
    assert asset['digest'].startswith('sha256:')
    lines.append(asset['digest'][7:] + '  ' + asset['name'])
manifest.write_text('\n'.join(lines) + '\n')
subprocess.run(['gh', 'release', 'upload', 'v1.5.8', str(manifest), '--clobber'], check=True)
print('All four RPM versions and release checksum manifest corrected.', flush=True)
