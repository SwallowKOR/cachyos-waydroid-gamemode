#!/bin/bash
# 파일명: $HOME/bin/waydroid-cage.sh

# -------------------------------
# 1. Waydroid 설치 확인
# -------------------------------
if ! command -v waydroid >/dev/null 2>&1; then
    echo "❌ Waydroid is not installed. Please install it first."
    exit 1
fi

# -------------------------------
# 2. 화면 환경 감지
# -------------------------------
RESOLUTION=$(xdpyinfo | awk '/dimensions/{print $2}')

# -------------------------------
# 3. Waydroid 컨테이너 시작
# -------------------------------
sudo systemctl start waydroid-container.service
if ! systemctl is-active --quiet waydroid-container.service; then
    echo "❌ Waydroid container failed to start."
    exit 1
fi

# -------------------------------
# 4. Kernel pid_max 설정
# -------------------------------
CACHE_FILE="$HOME/.cache/orig_kernel.pid_max"
mkdir -p "$(dirname "$CACHE_FILE")"
sysctl -a 2>/dev/null | grep kernel.pid_max | awk '{print $3}' > "$CACHE_FILE"
sudo sysctl -w kernel.pid_max=65535

# -------------------------------
# 5. Android 부팅 대기
# -------------------------------
while [[ -z $(waydroid shell getprop sys.boot_completed 2>/dev/null) ]]; do
    sleep 1
done

# -------------------------------
# 6. 환경별 Cage 실행
# -------------------------------
if [[ -n "$WAYLAND_DISPLAY" ]]; then
    # Wayland 환경
    echo "🌿 Running in Wayland session"
    if [ -z "$1" ]; then
        cage -- bash -c "
            wlr-randr --output X11-1 --custom-mode $RESOLUTION
            waydroid show-full-ui &
        "
    else
        APP="$1"
        cage -- bash -c "
            wlr-randr --output X11-1 --custom-mode $RESOLUTION
            waydroid session start &
            sleep 1
            waydroid app launch $APP &
            sleep 1
            waydroid show-full-ui &
        "
    fi
else
    # XWayland/GameMode 환경
    echo "🖥 Running in XWayland/GameMode session"
    export DISPLAY=:0
    export XAUTHORITY=$HOME/.Xauthority

    if [ -z "$1" ]; then
        cage -- bash -c "
            wlr-randr --output X11-1 --custom-mode $RESOLUTION
            waydroid show-full-ui &
        "
    else
        APP="$1"
        cage -- bash -c "
            waydroid session start &
            sleep 1
            waydroid app launch $APP &
            sleep 1
            waydroid show-full-ui &
        "
    fi
fi

# -------------------------------
# 7. 종료 시 클린업
# -------------------------------
while pgrep cage >/dev/null; do sleep 1; done

# kernel pid_max 복원
if [[ -f "$CACHE_FILE" ]]; then
    sudo sysctl -w kernel.pid_max=$(cat "$CACHE_FILE")
    rm -f "$CACHE_FILE"
fi

# Waydroid 컨테이너 종료
sudo systemctl stop waydroid-container.service
