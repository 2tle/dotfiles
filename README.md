# dotfiles

NixOS 설정을 기기별로 관리하기 위한 dotfiles 저장소입니다.

- 공통 개인 설정: `modules/nixos/common.nix`
- 기기별 설정: `hosts/<hostname>/configuration.nix`
- 하드웨어 설정: `hosts/<hostname>/hardware-configuration.nix`

현재 등록된 기기:

- `thinkpad-t14-gen2`
- `stringju-work` (새 PC 준비 중; 하드웨어 파일 교체 전에는 빌드 불가)

## 구조

```text
.
├── flake.nix
├── modules/
│   └── nixos/
│       └── common.nix
└── hosts/
    └── thinkpad-t14-gen2/
        ├── configuration.nix
        └── hardware-configuration.nix
```

## 새 기기에 적용하기

> 아래 명령의 `thinkpad-t14-gen2` 부분은 적용하려는 기기의 hostname으로 바꿉니다.

### 1. 저장소 클론

```bash
git clone https://github.com/<your-github-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. 기기별 디렉터리 준비

이미 저장소에 해당 기기가 있으면 이 단계는 건너뜁니다.

```bash
HOST=<new-hostname>
mkdir -p hosts/$HOST
sudo nixos-generate-config --show-hardware-config > hosts/$HOST/hardware-configuration.nix
cp hosts/thinkpad-t14-gen2/configuration.nix hosts/$HOST/configuration.nix
```

그리고 `hosts/$HOST/configuration.nix`에서 hostname을 수정합니다.

```nix
networking.hostName = "<new-hostname>";
```

필요하면 bootloader, GPU, 디스크, 노트북 전용 설정 등 device-specific 설정도 이 파일에 둡니다.

### 3. flake에 기기 추가

`flake.nix`의 `nixosConfigurations`에 새 host를 추가합니다.

```nix
<new-hostname> = nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./hosts/<new-hostname>/configuration.nix
  ];
};
```

### 4. 적용

먼저 빌드만 확인합니다.

```bash
sudo nixos-rebuild build --flake .#thinkpad-t14-gen2
```

문제가 없으면 적용합니다.

```bash
sudo nixos-rebuild switch --flake .#thinkpad-t14-gen2
```

## 현재 기기에서 바로 적용하기

이 저장소는 현재 `/etc/nixos/configuration.nix`를 기준으로 다음 설정을 분리했습니다.

- 공통 설정: locale, Fcitx5, SDDM, Hyprland, PipeWire, 사용자, 폰트, 공통 패키지
- `thinkpad-t14-gen2` 전용 설정: hostname, bootloader, hardware configuration

적용:

```bash
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#thinkpad-t14-gen2
```

## 설정 변경 workflow

```bash
cd ~/dotfiles
$EDITOR modules/nixos/common.nix              # 모든 기기에 적용할 개인 설정
$EDITOR hosts/thinkpad-t14-gen2/configuration.nix  # 이 기기에만 적용할 설정
sudo nixos-rebuild switch --flake .#thinkpad-t14-gen2
git status
git add .
git commit -m "Update nixos configuration"
git push
```

## `stringju-work` 준비 및 적용

**이 호스트는 아직 적용하면 안 됩니다.** `hosts/stringju-work/hardware-configuration.nix`는 빌드를 차단하는 자리표시자입니다. 대상 PC에서 다음을 준비하세요.

1. 대상 PC의 실제 하드웨어 설정을 생성/확인한 뒤 이 저장소의 `hosts/stringju-work/hardware-configuration.nix`를 **통째로 교체**합니다. 예: 대상 PC에서 `sudo nixos-generate-config --show-hardware-config > ~/dotfiles/hosts/stringju-work/hardware-configuration.nix`. 기존 설치의 `/etc/nixos/hardware-configuration.nix`가 정확하다면 복사해도 됩니다.
2. 대상 PC의 부팅 방식에 맞춰 `hosts/stringju-work/configuration.nix`에 부트로더(예: UEFI의 systemd-boot) 설정을 추가합니다. 현재 파일에는 부트로더 설정이 없습니다. 실제 기기의 기존 `system.stateVersion`도 확인합니다(`modules/nixos/common.nix`은 26.05). 값이 다르면 공통 파일을 바꾸지 말고 호스트에서 `system.stateVersion = lib.mkForce "기존값";`으로 덮어쓰세요.
3. `ip -br link`로 유선 인터페이스를 확인합니다. 현재 고정 IP 프로필은 이름을 모르므로 **모든 이더넷 인터페이스에 매칭**됩니다. NIC가 둘 이상이면 `connection."interface-name" = "enp...";`를 `hosts/stringju-work/configuration.nix`의 `stringju-work-wired.connection`에 추가하세요. 같은 LAN에서 `115.145.150.233`이 이 PC에 할당됐는지도 먼저 확인하세요. 잘못된 네트워크에서 적용하면 접속이 끊길 수 있으므로 원격 접속으로 바로 `switch`하지 마세요.
4. 배경 이미지를 `background/`에 넣고 git에 추가합니다(PNG/JPG/JPEG/BMP/WebP/SVG). 빌드 시 파일이 Nix store에 복사되므로, 이미지를 바꾸면 다시 빌드해야 합니다. 이미지들은 **파일 이름 순서로 1분마다 순환**합니다. `hyprpaper` 자체의 디렉터리·타이머 기능을 사용하므로 런타임 셸이나 `sleep` 루프는 없습니다. `contain` 모드로 화면 비율을 유지하고, 1024×1024 이미지 밖의 남는 화면은 흰색이 되도록 이 호스트의 `hyprpaper` 배경 캔버스를 패치했습니다.
5. Bongo Cat은 로그인 시 자동 실행되어 활성 창이 있는 모니터 상단을 따라갑니다. 키 입력이 안 잡히면 `bongocat-find-devices`로 장치를 확인하고 `hosts/stringju-work/configuration.nix`의 `keyboard_name`을 수정하세요. `input` 그룹 추가 후 재로그인이 필요하며, 이 그룹은 키보드 입력 장치에 대한 접근을 허용하므로 신뢰할 수 있는 사용자에게만 부여하세요.
6. OMP는 설치되지만 서비스 계정 인증은 포함되지 않습니다. 대상 PC에서 `omp` 실행 후 `/login openai-codex`, `/login opencode-go`를 각각 진행하세요. 인증 정보/API 키는 **공개 저장소에 커밋하지 마세요**.
7. Cloudflare WARP 클라이언트와 데몬은 설치·활성화됩니다. 현재 미니 PC처럼 Zero Trust 조직 `stringju`에 연결하려면 대상 PC에서 `warp-cli registration new stringju`로 브라우저 인증을 마친 뒤 `warp-cli connect`를 실행하세요. 기기 등록 정보는 `/var/lib/cloudflare-warp`에 로컬로 저장되며 공개 dotfiles에 포함되지 않습니다. 조직 정책이 Always On이면 이후 연결 상태는 정책에 따릅니다.
8. 한글 입력기는 공통 Fcitx5 설치를 사용하고, 이 호스트에서 영문(US)·한글을 기본 입력 그룹에 등록해 로그인 시 시작합니다. `Ctrl+Space`로 한/영 입력을 전환하세요. 기존 `~/.config/fcitx5/profile`이 있다면 사용자 설정이 시스템 기본값보다 우선하므로 Fcitx5 설정 도구에서 한글 입력기를 추가하거나 기존 프로필을 정리하세요.

적용 전/후 확인(대상 PC에서 실행):

```bash
cd ~/dotfiles
git add background hosts/stringju-work flake.nix flake.lock
sudo nixos-rebuild build --flake .#stringju-work
sudo nixos-rebuild switch --flake .#stringju-work
ip -4 addr; ip -4 route; resolvectl status
systemctl --user status fcitx5 stringju-wallpaper wayland-bongocat-follow-focus
systemctl status cloudflare-warp
warp-cli status
omp --version
```

설정한 IPv4는 `115.145.150.233/32`, 기본 경로는 `115.145.150.1`(on-link), DNS는 `8.8.8.8`입니다. 이 네트워크는 접속 중일 때만 적용되며 Wi-Fi/VPN이나 다른 연결이 DNS·경로 우선순위를 변경할 수 있습니다. 특히 현재 `stringju` WARP 조직 정책은 WARP+DoH 모드이므로 **WARP 연결 중 실제 DNS는 Cloudflare Gateway 정책을 따르고 8.8.8.8이 아닙니다**. WARP 연결이 끊긴 기본 유선 프로필에서는 8.8.8.8을 사용합니다. 공인 IP는 다른 기기에서 동시에 쓰지 마세요.

패키지는 `flake.lock`에 고정됩니다. 최신 26.05 안정판 패키지로 갱신하려면 `nix flake update` 후 빌드와 검증을 거쳐 적용하세요. 무조건 최상류 최신 Hyprland/Nix를 설치하는 방식은 아닙니다.

## `thinkpad-t14-gen2` 노트북 클라이언트

공통 단축키·로그인 배경·패키지를 사용하고, 미니PC와 동일한 Waybar·Fcitx5·순환 배경 설정을 적용합니다. Cloudflare WARP는 **클라이언트 전용**이며 미니PC의 포워딩·NAT·고정 IP·방화벽 신뢰 인터페이스나 Orca 서버 서비스를 사용하지 않습니다. Orca ADE는 앱 메뉴에서 실행하는 GUI 클라이언트입니다. AppImage는 첫 실행 전 노트북에서 `sudo systemctl start orca-ade-update.service`로 수동 설치해야 합니다.

```sh
sudo nixos-rebuild build --flake .#thinkpad-t14-gen2
sudo nixos-rebuild switch --flake .#thinkpad-t14-gen2
warp-cli registration new stringju  # 해당 조직에 등록할 때만 (브라우저 인증)
warp-cli connect
```

WARP 조직 등록 정보는 노트북의 로컬 상태에 저장됩니다. Bongo Cat은 로그인 시 화면 상단에 자동 실행되며, 키 입력이 안 잡히면 노트북에서 `bongocat-find-devices`로 실제 키보드 장치명을 확인해 `hosts/thinkpad-t14-gen2/configuration.nix`의 `inputDeviceNames`를 수정하세요. `input` 그룹 권한 적용에는 재로그인이 필요합니다. 노트북의 `synps/2-synaptics-touchpad`에만 Hyprland 포인터 감도 `0.6`을 적용합니다. 트랙포인트(`tpps/2-elan-trackpoint`)와 외장 마우스 감도는 그대로 유지합니다.

## `stringju-work` Orca 원격 서버

이 호스트에서는 부팅 시 `stringju` 사용자로 `orca serve`가 시작됩니다. WARP 인터페이스의 현재 IPv4를 연결 주소로 사용하며, 포트 6768은 기존 방화벽 설정상 **WARP를 통해서만** 접근할 수 있습니다. 로그인·GUI 창 없이 동작하며 앱 메뉴의 Orca 항목은 설치하지 않습니다. AppImage의 FHS 셸이 붙이는 `appimage-run-fhsenv:` 프롬프트 접두사도 제거해 원격 터미널에 `stringju@stringju-work`가 표시되도록 했습니다. `git`, `gh`, `ps`, `Xvfb`를 Orca AppImage 실행 환경에 포함해 프로젝트 탐색 및 헤드리스 시작 오류를 방지합니다. 자동 최신 버전 다운로드 타이머는 예기치 않은 버전·프로토콜 변경을 막기 위해 제거했습니다.

같은 사용자 프로필을 사용하는 GUI와 `orca serve`를 동시에 실행하지 마세요. 원격 터미널은 서버 재시작 후 새 셸을 열어야 변경된 프롬프트가 보입니다.

```bash
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#stringju-work
systemctl status orca-serve --no-pager
journalctl -u orca-serve -b --no-pager -n 80
```

서버 로그의 **새 페어링 URL은 비밀이므로 공유하지 마세요.** MacBook Orca의 Settings → Remote Orca Servers에서 새 서버를 등록하거나 기존 연결을 확인하세요. MacBook에서도 WARP를 켜고, 연결이 안 되면 `nc -vz <로그에 표시된 WARP IP> 6768`로 도달 여부를 검사하세요. 해당 조직의 사설망 라우팅 정책이 이 장치 간 통신을 허용해야 합니다. 기존 GUI가 사용한 주소/연결 토큰은 서버 모드 전환 후 다시 페어링해야 할 수 있습니다.

업데이트는 수동으로만 실행합니다. 먼저 서버를 중지하고 백업을 확인한 뒤 `sudo systemctl start orca-ade-update.service`, `sudo systemctl start orca-serve.service` 순서로 진행하세요.

## `stringju-work`에서 sops-nix 사용하기

이 호스트에만 sops-nix 모듈과 `sops`, `age`, `ssh-to-age` 명령을 설치했습니다. 현재 등록된 secret은 없으므로 암호화 파일을 준비하기 전에도 빌드할 수 있습니다. 시스템은 기존 `/etc/ssh/ssh_host_ed25519_key`로 복호화합니다. **이 개인 키는 git에 추가하지 마세요.** SSH 호스트 키를 교체하거나 OS를 재설치하기 전에는 키를 안전하게 백업하거나 암호화 파일을 새 수신자 키로 재암호화해야 합니다.

1. 적용: `sudo nixos-rebuild switch --flake .#stringju-work` (먼저 위의 호스트별 하드웨어·네트워크 설정을 확인하세요).
2. 편집용 개인 키를 생성해 안전하게 백업합니다(기존 키가 있으면 재생성하지 마세요):

   ```bash
   mkdir -p -m 700 ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   age-keygen -y ~/.config/sops/age/keys.txt          # 편집자 공개 키
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub      # 이 PC의 공개 키
   ```

3. 저장소 루트에 `.sops.yaml`을 만들고 출력된 **두 공개 키**를 넣습니다(아래 문자열은 예시 자리표시자입니다):

   ```yaml
   creation_rules:
     - path_regex: secrets/stringju-work\.yaml$
       age: >-
         age1YOUR_PERSONAL_PUBLIC_KEY,
         age1YOUR_HOST_PUBLIC_KEY
   ```

4. `mkdir -p secrets && sops secrets/stringju-work.yaml`로 파일을 열고, 편집기에서 `example: 실제값`처럼 입력·저장합니다. **평문 파일을 저장소에 만들거나 커밋하지 마세요.** `.sops.yaml`은 키 목록만 담고, `secrets/stringju-work.yaml`은 암호문이어야 합니다.
5. `hosts/stringju-work/configuration.nix`에 필요한 항목을 선언합니다(파일을 만든 다음):

   ```nix
   sops.defaultSopsFile = ../../secrets/stringju-work.yaml;
   sops.secrets.example = { }; # /run/secrets/example, 기본 root 전용
   ```

   서비스를 연결할 때는 암호 문자열 대신 `config.sops.secrets.example.path`를 해당 서비스의 파일 경로 옵션에 전달하세요. `git add .sops.yaml secrets/stringju-work.yaml hosts/stringju-work/configuration.nix` 후 `sudo nixos-rebuild switch --flake .#stringju-work`로 적용합니다. `sudo ls -l /run/secrets/example`로 배포 여부를 확인할 수 있습니다. `sops secrets/stringju-work.yaml`로 수정하고, 수신자를 바꾸면 `sops updatekeys secrets/stringju-work.yaml`을 실행하세요.

## 규칙

- 여러 기기에 공통으로 쓰는 설정은 `modules/nixos/common.nix`에 둡니다.
- hostname, hardware, bootloader, GPU, 디스크, 기기별 패키지는 `hosts/<hostname>/configuration.nix`에 둡니다.
- `/etc/nixos/hardware-configuration.nix`는 기기마다 다르므로 반드시 host 디렉터리에 따로 보관합니다.
- 비밀번호, 토큰, 개인 키의 **평문**은 git에 커밋하지 않습니다. sops로 암호화한 파일만 커밋합니다.
