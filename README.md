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
5. Bongo Cat은 로그인 시 자동 실행됩니다. 키 입력이 안 잡히면 `bongocat-find-devices`로 장치를 확인하고 `programs.wayland-bongocat.inputDeviceNames`를 기기별로 지정하세요. `input` 그룹 추가 후 재로그인이 필요하며, 이 그룹은 키보드 입력 장치에 대한 접근을 허용하므로 신뢰할 수 있는 사용자에게만 부여하세요.
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
systemctl --user status fcitx5 stringju-wallpaper wayland-bongocat
systemctl status cloudflare-warp
warp-cli status
omp --version
```

설정한 IPv4는 `115.145.150.233/32`, 기본 경로는 `115.145.150.1`(on-link), DNS는 `8.8.8.8`입니다. 이 네트워크는 접속 중일 때만 적용되며 Wi-Fi/VPN이나 다른 연결이 DNS·경로 우선순위를 변경할 수 있습니다. 특히 현재 `stringju` WARP 조직 정책은 WARP+DoH 모드이므로 **WARP 연결 중 실제 DNS는 Cloudflare Gateway 정책을 따르고 8.8.8.8이 아닙니다**. WARP 연결이 끊긴 기본 유선 프로필에서는 8.8.8.8을 사용합니다. 공인 IP는 다른 기기에서 동시에 쓰지 마세요.

패키지는 `flake.lock`에 고정됩니다. 최신 26.05 안정판 패키지로 갱신하려면 `nix flake update` 후 빌드와 검증을 거쳐 적용하세요. 무조건 최상류 최신 Hyprland/Nix를 설치하는 방식은 아닙니다.

## 규칙

- 여러 기기에 공통으로 쓰는 설정은 `modules/nixos/common.nix`에 둡니다.
- hostname, hardware, bootloader, GPU, 디스크, 기기별 패키지는 `hosts/<hostname>/configuration.nix`에 둡니다.
- `/etc/nixos/hardware-configuration.nix`는 기기마다 다르므로 반드시 host 디렉터리에 따로 보관합니다.
- 비밀번호, 토큰, 개인 키 같은 secret은 git에 커밋하지 않습니다.
