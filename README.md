# dotfiles

NixOS 설정을 기기별로 관리하기 위한 dotfiles 저장소입니다.

- 공통 개인 설정: `modules/nixos/common.nix`
- 기기별 설정: `hosts/<hostname>/configuration.nix`
- 하드웨어 설정: `hosts/<hostname>/hardware-configuration.nix`

현재 등록된 기기:

- `thinkpad-t14-gen2`

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

## 규칙

- 여러 기기에 공통으로 쓰는 설정은 `modules/nixos/common.nix`에 둡니다.
- hostname, hardware, bootloader, GPU, 디스크, 기기별 패키지는 `hosts/<hostname>/configuration.nix`에 둡니다.
- `/etc/nixos/hardware-configuration.nix`는 기기마다 다르므로 반드시 host 디렉터리에 따로 보관합니다.
- 비밀번호, 토큰, 개인 키 같은 secret은 git에 커밋하지 않습니다.
